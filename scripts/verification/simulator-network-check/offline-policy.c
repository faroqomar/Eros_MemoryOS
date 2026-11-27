#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/socket.h>
#include <unistd.h>

// Test-only Simulator helper. Apple deprecates this API; never ship this shim.
// The policy is irreversible for this process. Run only the opt-in isolated test.
int memoryos_install_offline_policy(char *error, size_t capacity) {
  typedef int (*install_fn)(const char *, uint64_t, char **);
  typedef void (*free_fn)(char *);
  install_fn install = (install_fn)dlsym(RTLD_DEFAULT, "sandbox_init");
  free_fn release = (free_fn)dlsym(RTLD_DEFAULT, "sandbox_free_error");
  if (!install || !release) {
    snprintf(error, capacity, "sandbox_init/sandbox_free_error unavailable: %s", dlerror());
    return -2;
  }
  const char *profile =
      "(version 1) (allow default) (deny network-outbound) "
      "(allow network-outbound (remote ip \"localhost:*\"))";
  char *detail = NULL;
  int result = install(profile, 0, &detail);
  int saved = errno;
  snprintf(error, capacity, "sandbox_init result=%d errno=%d detail=%s", result, saved,
           detail ? detail : "none");
  if (detail) release(detail);
  return result;
}

// Return the socket API errno, zero for an allowed successful connection/send.
// Reserved TEST-NET addresses avoid contact with a real service if policy fails.
int memoryos_probe_external(int family, int datagram) {
  int fd = socket(family, datagram == 1 || datagram == 3 ? SOCK_DGRAM : SOCK_STREAM, 0);
  if (fd < 0) return errno;
  if ((datagram == 0 || datagram == 2) && fcntl(fd, F_SETFL, O_NONBLOCK) < 0) {
    int saved = errno;
    close(fd);
    return saved;
  }
  int result;
  struct sockaddr_storage storage = {0};
  socklen_t length;
  if (family == AF_INET) {
    struct sockaddr_in *address = (struct sockaddr_in *)&storage;
    *address = (struct sockaddr_in){.sin_len = sizeof(*address), .sin_family = AF_INET,
                                   .sin_port = htons(9)};
    inet_pton(AF_INET, "192.0.2.1", &address->sin_addr);
    length = sizeof(*address);
  } else {
    struct sockaddr_in6 *address = (struct sockaddr_in6 *)&storage;
    *address = (struct sockaddr_in6){.sin6_len = sizeof(*address), .sin6_family = AF_INET6,
                                    .sin6_port = htons(9)};
    inet_pton(AF_INET6, "2001:db8::1", &address->sin6_addr);
    length = sizeof(*address);
  }
  if (datagram == 1) {
    result = (int)sendto(fd, "x", 1, 0, (struct sockaddr *)&storage, length);
  } else if (datagram == 2) {
    sa_endpoints_t endpoints = {.sae_dstaddr = (struct sockaddr *)&storage,
                               .sae_dstaddrlen = length};
    result = connectx(fd, &endpoints, SAE_ASSOCID_ANY, 0, NULL, 0, NULL, NULL);
  } else if (datagram == 3) {
    char data = 'x';
    struct iovec vector = {.iov_base = &data, .iov_len = 1};
    struct msghdr message = {.msg_name = &storage, .msg_namelen = length,
                            .msg_iov = &vector, .msg_iovlen = 1};
    result = (int)sendmsg(fd, &message, 0);
  } else {
    result = connect(fd, (struct sockaddr *)&storage, length);
  }
  int saved = result < 0 ? errno : 0;
  close(fd);
  return saved;
}

int memoryos_probe_loopback(void) {
  int server = socket(AF_INET, SOCK_STREAM, 0);
  if (server < 0) return errno;
  struct sockaddr_in address = {.sin_len = sizeof(address), .sin_family = AF_INET,
                               .sin_addr = {.s_addr = htonl(INADDR_LOOPBACK)}};
  if (bind(server, (struct sockaddr *)&address, sizeof(address)) || listen(server, 1)) {
    int saved = errno;
    close(server);
    return saved;
  }
  socklen_t size = sizeof(address);
  if (getsockname(server, (struct sockaddr *)&address, &size)) {
    int saved = errno;
    close(server);
    return saved;
  }
  int client = socket(AF_INET, SOCK_STREAM, 0);
  if (client < 0) { int saved = errno; close(server); return saved; }
  int result = connect(client, (struct sockaddr *)&address, sizeof(address));
  int saved = result < 0 ? errno : 0;
  close(client);
  close(server);
  return saved;
}
