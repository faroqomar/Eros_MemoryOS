#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>

// Mach-O interpose tuple layout: Apple's dyld include/mach-o/dyld-interposing.h.
// https://github.com/apple-oss-distributions/dyld/blob/main/include/mach-o/dyld-interposing.h
// This helper targets arm64 Simulator only; it does not ship in the application.
#define MEMORYOS_INTERPOSE(wrapper, original) \
  __attribute__((used,section("__DATA,__interpose,interposing"))) \
  static const struct { const void *substitute; const void *symbol; } \
  memoryos_interpose_##original = {(const void *)(uintptr_t)&wrapper, \
                                  (const void *)(uintptr_t)&original};

// Verification only. Public socket API fault injection, NOT a kernel sandbox.
// Inject at testhost launch so calls can be interposed after explicit test activation.
// Denial starts in memoryos_api_fault_install; pre-test initialization is outside coverage.
static _Atomic uint64_t rejected;
static _Atomic uint64_t forwarded_loopback;
static _Atomic int active;
int memoryos_api_fault_install(void) {
  const char *value = getenv("MEMORYOS_API_NETWORK_FAULTS");
  atomic_store(&active, value && strcmp(value, "1") == 0);
  return atomic_load(&active) ? 0 : -1;
}
int memoryos_api_fault_active(void) { return atomic_load(&active); }
uint64_t memoryos_api_fault_rejected(void) { return atomic_load(&rejected); }
uint64_t memoryos_api_fault_loopback(void) { return atomic_load(&forwarded_loopback); }

static int nonlocal(const struct sockaddr *address) {
  if (!address) return 0;
  if (address->sa_family == AF_INET) {
    uint32_t host = ntohl(((const struct sockaddr_in *)address)->sin_addr.s_addr);
    return (host >> 24) != 127;
  }
  if (address->sa_family == AF_INET6) {
    const struct in6_addr *ip = &((const struct sockaddr_in6 *)address)->sin6_addr;
    if (IN6_IS_ADDR_LOOPBACK(ip)) return 0;
    if (IN6_IS_ADDR_V4MAPPED(ip)) return ip->s6_addr[12] != 127;
    return 1;
  }
  return 0; // Preserve Unix-domain XCTest/control traffic.
}
static int denied(int descriptor, const struct sockaddr *address) {
  if (!active) return 0;
  struct sockaddr_storage peer;
  socklen_t length = sizeof(peer);
  if (!address && getpeername(descriptor, (struct sockaddr *)&peer, &length) == 0)
    address = (struct sockaddr *)&peer;
  if (nonlocal(address)) {
    atomic_fetch_add(&rejected, 1);
    errno = EPERM;
    return 1;
  }
  if (address && (address->sa_family == AF_INET || address->sa_family == AF_INET6))
    atomic_fetch_add(&forwarded_loopback, 1);
  return 0;
}
static int fault_connect(int fd, const struct sockaddr *address, socklen_t length) {
  return denied(fd, address) ? -1 : connect(fd, address, length);
}
static int fault_connectx(int fd, const sa_endpoints_t *endpoints, sae_associd_t association,
                          unsigned int flags, const struct iovec *data, unsigned int count,
                          size_t *written, sae_connid_t *connection) {
  return denied(fd, endpoints ? endpoints->sae_dstaddr : NULL) ? -1 :
      connectx(fd, endpoints, association, flags, data, count, written, connection);
}
static ssize_t fault_sendto(int fd, const void *data, size_t length, int flags,
                            const struct sockaddr *address, socklen_t size) {
  return denied(fd, address) ? -1 : sendto(fd, data, length, flags, address, size);
}
static ssize_t fault_sendmsg(int fd, const struct msghdr *message, int flags) {
  return denied(fd, message ? message->msg_name : NULL) ? -1 : sendmsg(fd, message, flags);
}
static int fault_getaddrinfo(const char *host, const char *service,
                             const struct addrinfo *hints, struct addrinfo **result) {
  if (active && host && strcmp(host, "localhost") != 0 && strcmp(host, "127.0.0.1") != 0
      && strcmp(host, "::1") != 0) {
    atomic_fetch_add(&rejected, 1);
    if (result) *result = NULL;
    return EAI_AGAIN;
  }
  return getaddrinfo(host, service, hints, result);
}
MEMORYOS_INTERPOSE(fault_connect, connect)
MEMORYOS_INTERPOSE(fault_connectx, connectx)
MEMORYOS_INTERPOSE(fault_sendto, sendto)
MEMORYOS_INTERPOSE(fault_sendmsg, sendmsg)
MEMORYOS_INTERPOSE(fault_getaddrinfo, getaddrinfo)
