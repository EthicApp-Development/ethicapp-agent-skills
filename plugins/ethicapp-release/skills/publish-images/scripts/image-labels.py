#!/usr/bin/env python3
"""Print the registry digest and OCI labels of published GHCR images.

Usage: image-labels.py [--owner OWNER] [--expect-revision SHA] TAG PACKAGE...

  OWNER defaults to ethicapp-development. PACKAGE is the GHCR package name,
  for example ethicapp-auth-backend or ethicapp-ai-additions-catalog.
  Prints one tab-separated line per package:
    package, tag, digest, revision label, version label, created label
  Authenticates with GH_TOKEN, or with `gh auth token` when GH_TOKEN is
  unset (the token needs read:packages for private packages).

Exit codes:
  0  every package has the tag (and the expected revision, when given)
  2  a package does not have the tag
  3  a revision label differs from --expect-revision, or a version label
     differs from TAG (missing version labels are reported, not failed,
     since images built before the label existed lack it)
  1  usage or network error
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

ACCEPT = ", ".join([
    "application/vnd.oci.image.index.v1+json",
    "application/vnd.docker.distribution.manifest.list.v2+json",
    "application/vnd.oci.image.manifest.v1+json",
    "application/vnd.docker.distribution.manifest.v2+json",
])


def user_token():
    token = os.environ.get("GH_TOKEN")
    if token:
        return token
    return subprocess.run(["gh", "auth", "token"], check=True,
                          capture_output=True, text=True).stdout.strip()


def registry_token(owner, package, token):
    req = urllib.request.Request(
        f"https://ghcr.io/token?scope=repository:{owner}/{package}:pull")
    basic = base64.b64encode(f"x:{token}".encode()).decode()
    req.add_header("Authorization", f"Basic {basic}")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp)["token"]


def fetch(owner, package, path, bearer, accept=ACCEPT):
    req = urllib.request.Request(f"https://ghcr.io/v2/{owner}/{package}/{path}")
    req.add_header("Authorization", f"Bearer {bearer}")
    req.add_header("Accept", accept)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.load(resp), resp.headers.get("Docker-Content-Digest", "")


def inspect(owner, package, tag, token):
    bearer = registry_token(owner, package, token)
    manifest, digest = fetch(owner, package, f"manifests/{tag}", bearer)
    if "manifests" in manifest:
        chosen = next(
            (m for m in manifest["manifests"]
             if m.get("platform", {}).get("os") == "linux"
             and m.get("platform", {}).get("architecture") == "amd64"),
            manifest["manifests"][0])
        manifest, _ = fetch(owner, package, f"manifests/{chosen['digest']}", bearer)
    config, _ = fetch(owner, package, f"blobs/{manifest['config']['digest']}",
                      bearer, accept="*/*")
    labels = (config.get("config") or {}).get("Labels") or {}
    return digest, labels


def main():
    parser = argparse.ArgumentParser(add_help=True)
    parser.add_argument("--owner", default="ethicapp-development")
    parser.add_argument("--expect-revision")
    parser.add_argument("tag")
    parser.add_argument("packages", nargs="+")
    args = parser.parse_args()

    try:
        token = user_token()
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"no GitHub token: {exc}", file=sys.stderr)
        return 1

    status = 0
    for package in args.packages:
        try:
            digest, labels = inspect(args.owner, package, args.tag, token)
        except urllib.error.HTTPError as exc:
            if exc.code == 404:
                print(f"{package}\t{args.tag}\tMISSING")
                status = max(status, 2)
                continue
            print(f"{package}: HTTP {exc.code}", file=sys.stderr)
            return 1
        except urllib.error.URLError as exc:
            print(f"{package}: {exc.reason}", file=sys.stderr)
            return 1
        revision = labels.get("org.opencontainers.image.revision", "-")
        version = labels.get("org.opencontainers.image.version", "-")
        created = labels.get("org.opencontainers.image.created", "-")
        print("\t".join([package, args.tag, digest, revision, version, created]))
        if args.expect_revision and not revision.startswith(args.expect_revision):
            print(f"{package}: revision {revision} != expected {args.expect_revision}",
                  file=sys.stderr)
            status = max(status, 3)
        if version not in ("-", args.tag):
            print(f"{package}: version label {version} != {args.tag}", file=sys.stderr)
            status = max(status, 3)
    return status


if __name__ == "__main__":
    sys.exit(main())
