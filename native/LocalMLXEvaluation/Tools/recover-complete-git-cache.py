#!/usr/bin/env python3
"""Recover a complete genuine shallow Git cache from an immutable upstream archive.

Every archive file contributes to the original commit's root-tree hash. No SDK source
is patched, no promisor repository is cloned, and no Git upload-pack is rewritten.
"""

import argparse
import hashlib
import io
import json
import os
import re
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import time
import zlib

import requests

PACKAGE = Path(__file__).resolve().parents[1]
EVIDENCE = PACKAGE.parent / "verification/local-ai-step1/resume"
CACHE = Path.home() / "Library/Caches/MemoryOS-AI-Evaluation/mlx-canonical-shallow-spm"
ENVIRONMENT = dict(os.environ, GIT_NO_LAZY_FETCH="1")
for key in ["GIT_DIR", "GIT_COMMON_DIR", "GIT_WORK_TREE", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"]:
    ENVIRONMENT.pop(key, None)


def git(repository, *arguments):
    return subprocess.check_output(["/usr/bin/git", "--no-lazy-fetch", "-C", str(repository), *arguments], env=ENVIRONMENT)


def object_id(kind, data):
    return hashlib.sha1(kind.encode() + b" " + str(len(data)).encode() + b"\0" + data).hexdigest()


def store(repository, kind, data):
    body = kind.encode() + b" " + str(len(data)).encode() + b"\0" + data
    identity = hashlib.sha1(body).hexdigest()
    path = repository / "objects" / identity[:2] / identity[2:]
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix(".memoryos-archive")
        temporary.write_bytes(zlib.compress(body))
        temporary.replace(path)
    return identity


def download(url, target):
    if target.is_file():
        return target.read_bytes()
    partial = target.with_suffix(".partial")
    attempt = 0
    while True:
        attempt += 1
        offset = partial.stat().st_size if partial.exists() else 0
        headers = {"Accept-Encoding": "identity"}
        if offset:
            headers["Range"] = "bytes=" + str(offset) + "-"
        request_url = url if attempt == 1 else url + "?memoryos_archive_retry=" + str(time.time_ns())
        try:
            with requests.get(request_url, headers=headers, stream=True, timeout=(60, 120)) as response:
                if response.status_code in [400, 401, 403, 404, 410]:
                    raise RuntimeError("Permanent immutable archive HTTP failure: " + str(response.status_code))
                response.raise_for_status()
                range_end = None
                if response.status_code == 206:
                    match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", response.headers.get("Content-Range", ""))
                    if not match or int(match[1]) != offset or not offset <= int(match[2]) < int(match[3]):
                        raise RuntimeError("The archive byte range differs from the retained prefix.")
                    range_end = int(match[2]) + 1
                elif response.status_code != 200:
                    raise RuntimeError("Unsupported archive HTTP response.")
                print(json.dumps({"event": "archive-response", "status": response.status_code,
                                  "retainedBytes": offset, "contentLength": response.headers.get("Content-Length")}), flush=True)
                # A server may ignore Range. Compare its repeated prefix byte-for-byte,
                # then append only new bytes. Transport failures preserve prior progress.
                seen = offset if response.status_code == 206 else 0
                if not partial.exists():
                    partial.touch()
                with partial.open("rb") as prefix, partial.open("ab") as output:
                    for chunk in response.iter_content(65536):
                        compare_count = min(len(chunk), max(0, offset - seen))
                        if prefix.read(compare_count) != chunk[:compare_count]:
                            raise RuntimeError("An immutable archive response differs from the retained prefix.")
                        output.write(chunk[compare_count:])
                        output.flush()
                        seen += len(chunk)
                        print(json.dumps({"event": "archive-progress", "bytes": max(offset, seen)}), flush=True)
                if seen < offset or range_end is not None and seen != range_end:
                    raise requests.ConnectionError("Incomplete archive response.")
                partial.replace(target)
                return target.read_bytes()
        except RuntimeError:
            raise
        except requests.RequestException as error:
            print(json.dumps({"event": "archive-transport-retry", "attempt": attempt, "errorType": type(error).__name__}), flush=True)
            time.sleep(min(2 * attempt, 30))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity", required=True)
    parser.add_argument("--source-cache", type=Path, required=True)
    parser.add_argument("--upstream", required=True, help="Public GitHub owner/name")
    parser.add_argument("--revision", required=True)
    parser.add_argument("--tag")
    arguments = parser.parse_args()
    source = arguments.source_cache.resolve()
    revision = git(source, "rev-parse", arguments.revision + "^{commit}").decode().strip()
    commit = git(source, "cat-file", "commit", revision)
    if object_id("commit", commit) != revision:
        raise RuntimeError("The original pinned commit object is invalid.")
    root = next(line.split()[1] for line in commit.decode().splitlines() if line.startswith("tree "))
    origin = git(source, "remote", "get-url", "origin").decode().strip()
    if origin.removesuffix(".git") != "https://github.com/" + arguments.upstream:
        raise RuntimeError("The source cache origin differs from the reviewed upstream URL.")
    destination = CACHE / "repositories" / source.name
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        subprocess.run(["/usr/bin/git", "--no-lazy-fetch", "init", "--bare", str(destination)], env=ENVIRONMENT, check=True, capture_output=True)
        git(destination, "remote", "add", "origin", origin)
    if git(destination, "remote", "get-url", "origin").decode().strip() != origin:
        raise RuntimeError("Preserved a recovery cache with an unexpected origin.")
    config = (destination / "config").read_text().lower()
    if "promisor" in config or "partialclone" in config:
        raise RuntimeError("Never recover into or clone a promisor cache.")
    archives = CACHE / "verified-archives"
    archives.mkdir(parents=True, exist_ok=True)
    archive_path = archives / (arguments.identity + "-" + revision + ".tar.gz")
    archive = download("https://codeload.github.com/" + arguments.upstream + "/tar.gz/" + revision, archive_path)
    nodes = {}
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as members:
        for member in members:
            pieces = PurePosixPath(member.name).parts
            if not pieces or any(part in ["..", "."] for part in pieces) or member.name.startswith("/"):
                raise RuntimeError("Unsafe path in upstream archive.")
            path = "/".join(pieces[1:])
            if not path or member.isdir():
                continue
            if member.issym():
                data, mode = member.linkname.encode(), "120000"
            elif member.isfile():
                data, mode = members.extractfile(member).read(), "100755" if member.mode & 0o111 else "100644"
            else:
                raise RuntimeError("Unsupported archive entry; no files were extracted.")
            if path in nodes:
                raise RuntimeError("Duplicate archive path.")
            nodes[path] = (mode, store(destination, "blob", data))
    # GitHub archives omit submodule contents. Preserve their exact Gitlinks.
    snapshot_path = EVIDENCE / ("mlx-snapshot-" + arguments.identity + ".json")
    links = []
    if snapshot_path.exists():
        snapshot = json.loads(snapshot_path.read_text())
        if snapshot["revision"] == revision:
            if snapshot["rootTreeSHA1"] != root:
                raise RuntimeError("The source receipt root differs from the pinned commit.")
            links = snapshot["gitlinks"]
    for link in links:
        nodes[link["path"]] = ("160000", link["sha"])
    directories = {""}
    for path in nodes:
        parent = PurePosixPath(path).parent
        while str(parent) != ".":
            directories.add(str(parent))
            parent = parent.parent
    for directory in sorted(directories, key=lambda value: (value.count("/"), len(value)), reverse=True):
        prefix = directory + "/" if directory else ""
        entries = [(path[len(prefix):], mode, identity) for path, (mode, identity) in nodes.items()
                   if path.startswith(prefix) and "/" not in path[len(prefix):]]
        entries.sort(key=lambda entry: entry[0].encode() + (b"/" if entry[1] == "40000" else b""))
        body = b"".join(mode.encode() + b" " + name.encode() + b"\0" + bytes.fromhex(identity) for name, mode, identity in entries)
        identity = store(destination, "tree", body)
        if directory:
            nodes[directory] = ("40000", identity)
        elif identity != root:
            raise RuntimeError("The complete archive tree differs from the original pinned Git root; cache remains unreferenced.")
    store(destination, "commit", commit)
    boundary = destination / "shallow"
    boundaries = set(boundary.read_text().splitlines()) if boundary.exists() else set()
    boundaries.add(revision)
    boundary.write_text("\n".join(sorted(boundaries)) + "\n")
    git(destination, "update-ref", "refs/heads/memoryos-reviewed", revision)
    git(destination, "symbolic-ref", "HEAD", "refs/heads/memoryos-reviewed")
    if arguments.tag:
        tag_ref = "refs/tags/" + arguments.tag
        if git(source, "rev-parse", tag_ref + "^{commit}").decode().strip() != revision:
            raise RuntimeError("The genuine upstream tag differs from the reviewed commit.")
        tag_identity = git(source, "rev-parse", tag_ref).decode().strip()
        cursor = tag_identity
        while git(source, "cat-file", "-t", cursor).decode().strip() == "tag":
            body = git(source, "cat-file", "tag", cursor)
            if store(destination, "tag", body) != cursor:
                raise RuntimeError("An upstream annotated tag differs from its original Git identity.")
            cursor = next(line.split()[1] for line in body.decode().splitlines() if line.startswith("object "))
        git(destination, "update-ref", tag_ref, tag_identity)
    fsck = git(destination, "fsck", "--full", "--no-dangling").decode()
    receipt = {"identity": arguments.identity, "origin": origin, "revision": revision, "rootTreeSHA1": root,
               "genuineShallowBoundary": True, "promisor": False, "sourcePatched": False,
               "archiveSHA256": hashlib.sha256(archive).hexdigest(), "archiveBytes": len(archive),
               "cache": str(destination), "fsck": fsck, "canonicalResolutionVerified": False}
    (EVIDENCE / ("mlx-complete-cache-" + arguments.identity + ".json")).write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps(receipt), flush=True)


if __name__ == "__main__":
    main()
