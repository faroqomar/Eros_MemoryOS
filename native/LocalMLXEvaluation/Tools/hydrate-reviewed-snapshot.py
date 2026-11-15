#!/usr/bin/env python3
"""Materialize verified SDK source for temporary integration; never use local Git upload-pack."""

import argparse
import base64
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import subprocess
import threading
import time
import urllib.parse
import zlib

import requests

PACKAGE = Path(__file__).resolve().parents[1]
EVIDENCE = PACKAGE.parent / "verification/local-ai-step1/resume"
SNAPSHOTS = Path.home() / "Library/Caches/MemoryOS-AI-Evaluation/mlx-verified-snapshots"
LOCAL = threading.local()
LOCK = threading.Lock()


def git_environment():
    environment = dict(os.environ, GIT_NO_LAZY_FETCH="1")
    for key in ["GIT_DIR", "GIT_COMMON_DIR", "GIT_WORK_TREE", "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"]:
        environment.pop(key, None)
    return environment


def git(repository, *arguments):
    return subprocess.check_output(
        ["/usr/bin/git", "--no-lazy-fetch", "-C", str(repository), *arguments],
        env=git_environment(),
    )


def api(upstream, endpoint):
    while True:
        result = subprocess.run(
            ["gh", "api", "repos/" + upstream + "/git/" + endpoint], capture_output=True
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
        if any(code in result.stderr for code in [b"HTTP 400", b"HTTP 401", b"HTTP 404", b"HTTP 410"]):
            raise RuntimeError("Permanent upstream tree API failure.")
        print(json.dumps({"event": "api-transport-retry", "repository": upstream}), flush=True)
        time.sleep(10)


def store(repository, kind, data, expected):
    body = kind.encode() + b" " + str(len(data)).encode() + b"\0" + data
    actual = hashlib.sha1(body).hexdigest()
    if actual != expected:
        raise RuntimeError("A source object differs from the pinned Git identity.")
    target = repository / "objects" / actual[:2] / actual[2:]
    if not target.exists():
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + ".memoryos-" + str(threading.get_ident()))
        temporary.write_bytes(zlib.compress(body))
        os.replace(temporary, target)


def raw(upstream, revision, path, expected):
    if not hasattr(LOCAL, "session"):
        LOCAL.session = requests.Session()
    url = "https://raw.githubusercontent.com/" + upstream + "/" + revision + "/" + urllib.parse.quote(path, safe="/")
    attempt = 0
    while True:
        attempt += 1
        try:
            response = LOCAL.session.get(url, timeout=(60, 120))
            if response.status_code in (400, 401, 403, 404, 410):
                raise RuntimeError("Permanent source HTTP failure: " + str(response.status_code))
            response.raise_for_status()
            data = response.content
            identity = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
            if identity != expected:
                # GitHub's raw route can dereference a symbolic link. The object API is exact.
                payload = api(upstream, "blobs/" + expected)
                data = base64.b64decode(payload["content"])
                identity = hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
                if identity != expected:
                    raise RuntimeError("A source blob differs from the pinned Git identity.")
            return data
        except RuntimeError:
            raise
        except Exception as error:
            print(json.dumps({"event": "raw-transport-retry", "path": path,
                              "attempt": attempt, "errorType": type(error).__name__}), flush=True)
            time.sleep(min(attempt * 2, 20))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", required=True, type=Path)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument("--identity", required=True)
    parser.add_argument("--roots", nargs="*", default=["Sources", "Source", "Libraries"])
    parser.add_argument("--object-cache", type=Path, action="append", default=[])
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--snapshot-root", type=Path)
    parser.add_argument("--scoped-tree", action="store_true")
    arguments = parser.parse_args()
    repository = arguments.cache.resolve()
    revision = git(repository, "rev-parse", arguments.revision + "^{commit}").decode().strip()
    commit = git(repository, "cat-file", "commit", revision)
    if hashlib.sha1(b"commit " + str(len(commit)).encode() + b"\0" + commit).hexdigest() != revision:
        raise RuntimeError("Pinned commit identity mismatch.")
    root = next(line.split()[1] for line in commit.decode().splitlines() if line.startswith("tree "))
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    suffix = "-scoped" if arguments.scoped_tree else ""
    tree_file = EVIDENCE / ("mlx-tree-" + arguments.identity + "-" + root + suffix + ".json")
    if tree_file.exists():
        payload = json.loads(tree_file.read_text())
    else:
        if arguments.scoped_tree:
            root_payload = api(arguments.repository, "trees/" + root)
            payload = dict(root_payload, tree=list(root_payload["tree"]), verifiedDirectories=[""])
            for scope in arguments.roots:
                entry = next((item for item in root_payload["tree"] if item["path"] == scope and item["type"] == "tree"), None)
                if entry is None:
                    continue
                scoped = api(arguments.repository, "trees/" + entry["sha"] + "?recursive=1")
                if scoped.get("truncated") or scoped.get("sha") != entry["sha"]:
                    raise RuntimeError("The scoped source tree does not match its pinned Git identity.")
                payload["verifiedDirectories"].append(scope)
                for item in scoped["tree"]:
                    payload["tree"].append(dict(item, path=scope + "/" + item["path"]))
                    if item["type"] == "tree":
                        payload["verifiedDirectories"].append(scope + "/" + item["path"])
        else:
            payload = api(arguments.repository, "trees/" + root + "?recursive=1")
        tree_file.write_text(json.dumps(payload, indent=2) + "\n")
    if payload.get("truncated") or payload.get("sha") != root:
        raise RuntimeError("The upstream recursive tree does not match the pinned root.")
    children = {"": []}
    expected_trees = {"": root}
    for entry in payload["tree"]:
        if entry["type"] == "tree":
            children[entry["path"]] = []
            expected_trees[entry["path"]] = entry["sha"]
    for entry in payload["tree"]:
        parent, _, name = entry["path"].rpartition("/")
        children[parent].append(dict(entry, path=name))
    for directory in sorted(children, key=lambda value: (value.count("/"), len(value)), reverse=True):
        if directory not in payload.get("verifiedDirectories", children):
            continue
        entries = sorted(children[directory], key=lambda item: item["path"].encode() + (b"/" if item["type"] == "tree" else b""))
        body = b"".join(item["mode"].lstrip("0").encode() + b" " + item["path"].encode()
                        + b"\0" + bytes.fromhex(item["sha"]) for item in entries)
        store(repository, "tree", body, expected_trees[directory])
    selected = []
    links = []
    for entry in payload["tree"]:
        path = entry["path"]
        if entry["type"] == "commit":
            links.append(entry)
        if entry["type"] != "blob":
            continue
        if "/" not in path or any(path == scope or path.startswith(scope + "/") for scope in arguments.roots):
            selected.append(entry)
    snapshot = arguments.snapshot_root or SNAPSHOTS / arguments.identity
    snapshot = snapshot.resolve()
    if not snapshot.is_relative_to(SNAPSHOTS.resolve()):
        raise RuntimeError("Keep temporary source snapshots inside the isolated MLX snapshot cache.")
    snapshot.mkdir(parents=True, exist_ok=True)
    for directory in children:
        (snapshot / directory).mkdir(parents=True, exist_ok=True)
    completed = []

    def materialize(entry):
        path, expected = entry["path"], entry["sha"]
        target = snapshot / path
        data = None
        for cache in [repository, *arguments.object_cache]:
            cached = subprocess.run(
                ["/usr/bin/git", "--no-lazy-fetch", "-C", str(cache), "cat-file", "blob", expected],
                env=git_environment(), capture_output=True,
            )
            if cached.returncode == 0:
                data = cached.stdout
                break
        if data is None:
            data = raw(arguments.repository, revision, path, expected)
        store(repository, "blob", data, expected)
        if entry["mode"] == "120000":
            link = data.decode()
            if not (target.parent / link).resolve().is_relative_to(snapshot.resolve()):
                raise RuntimeError("A source link escapes the reviewed snapshot.")
            if target.is_symlink():
                if os.readlink(target) != link:
                    raise RuntimeError("An existing snapshot link differs from upstream.")
            elif target.exists():
                raise RuntimeError("An existing snapshot file conflicts with an upstream link.")
            else:
                target.symlink_to(link)
        elif target.is_symlink():
            raise RuntimeError("An existing snapshot link conflicts with a regular upstream file.")
        elif target.exists():
            if target.read_bytes() != data:
                raise RuntimeError("An existing snapshot file differs from upstream; preserved it.")
        else:
            target.write_bytes(data)
            if entry["mode"] == "100755":
                target.chmod(0o755)
        record = {"path": path, "gitBlobSHA1": expected, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
        with LOCK:
            completed.append(record)
            with (EVIDENCE / ("mlx-hydration-" + arguments.identity + ".jsonl")).open("a") as log:
                log.write(json.dumps(record) + "\n")
            if len(completed) % 25 == 0 or len(completed) == len(selected):
                print(json.dumps({"identity": arguments.identity, "completed": len(completed), "total": len(selected)}), flush=True)

    print(json.dumps({"identity": arguments.identity, "revision": revision, "files": len(selected),
                      "trees": len(children), "gitlinks": len(links)}), flush=True)
    if not 1 <= arguments.workers <= 4:
        raise RuntimeError("Use one to four bounded source hydration workers.")
    with concurrent.futures.ThreadPoolExecutor(max_workers=arguments.workers) as executor:
        list(executor.map(materialize, selected))
    receipt = {"repository": arguments.repository, "revision": revision, "rootTreeSHA1": root,
               "sourceRoots": arguments.roots, "temporaryIntegrationOnly": True,
               "canonicalResolutionVerified": False, "gitlinks": links, "files": completed}
    manifest = EVIDENCE / ("mlx-snapshot-" + arguments.identity + ".json")
    manifest.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"snapshot": str(snapshot), "completeSelectedSources": True,
                      "canonicalResolutionVerified": False, "manifest": str(manifest)}), flush=True)


if __name__ == "__main__":
    main()
