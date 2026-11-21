#!/usr/bin/env python3
"""Zero-dependency App Store Connect API helper for Chimmo CI.

Uses only Python 3 standard library + `openssl` (preinstalled on macOS/Linux).
Commands:
  python3 Tools/asc.py ensure-bundle-ids app.chimmo
  python3 Tools/asc.py check-app app.chimmo
  python3 Tools/asc.py sync-whats-new --bundle-id app.chimmo --build 101 --version 0.1.0 --changelog CHANGELOG.md

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (or --key-path).
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request

API_BASE = "https://api.appstoreconnect.apple.com/v1"
MAX_WHATS_NEW_CHARS = 4000


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def der_ecdsa_to_raw(der: bytes, size: int = 32) -> bytes:
    idx = 0
    if idx >= len(der) or der[idx] != 0x30:
        raise ValueError("Invalid DER signature: missing SEQUENCE tag")
    idx += 1
    seq_len = der[idx]
    idx += 1
    if seq_len & 0x80:
        idx += seq_len & 0x7F

    parts: list[bytes] = []
    for _ in range(2):
        if der[idx] != 0x02:
            raise ValueError("Invalid DER signature: missing INTEGER tag")
        idx += 1
        nlen = der[idx]
        idx += 1
        val = der[idx : idx + nlen]
        idx += nlen
        val = val.lstrip(b"\x00")
        if len(val) > size:
            raise ValueError("ECDSA integer larger than expected curve size")
        parts.append(val.rjust(size, b"\x00"))
    return parts[0] + parts[1]


def make_jwt(key_id: str, issuer_id: str, key_path: str, ttl_seconds: int = 1000) -> str:
    now = int(time.time())
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}, separators=(",", ":")).encode("utf-8"))
    payload = b64url(
        json.dumps({"iss": issuer_id, "iat": now, "exp": now + ttl_seconds, "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode("utf-8")
    )
    signing_input = f"{header}.{payload}"
    proc = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input.encode("ascii"),
        capture_output=True,
        check=True,
    )
    raw_sig = der_ecdsa_to_raw(proc.stdout, 32)
    return f"{signing_input}.{b64url(raw_sig)}"


class ASCClient:
    def __init__(self, key_id: str, issuer_id: str, key_path: str):
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.key_path = key_path
        self._token = ""
        self._token_exp = 0.0

    def _get_token(self) -> str:
        now = time.time()
        if not self._token or now >= self._token_exp - 60:
            self._token = make_jwt(self.key_id, self.issuer_id, self.key_path)
            self._token_exp = now + 1000
        return self._token

    def request(self, method: str, path: str, body: dict | None = None) -> dict:
        url = path if path.startswith("http") else f"{API_BASE}{path}"
        data = json.dumps(body).encode("utf-8") if body is not None else None
        req = urllib.request.Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {self._get_token()}")
        req.add_header("Accept", "application/json")
        if data is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                raw = resp.read()
                return json.loads(raw.decode("utf-8")) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"ASC {method} {path} failed ({e.code}): {detail[:500]}") from e


def resolve_key_file(key_path: str | None) -> tuple[str, str | None]:
    if key_path:
        return key_path, None
    p8 = os.environ.get("ASC_KEY_P8", "")
    if not p8:
        raise RuntimeError("Missing ASC_KEY_P8 or --key-path")
    fd, tmp = tempfile.mkstemp(prefix="asc_key_", suffix=".p8")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(p8)
    os.chmod(tmp, 0o600)
    return tmp, tmp


def ensure_bundle_ids(client: ASCClient, ids: list[str], app_name: str = "Chimmo") -> None:
    for identifier in ids:
        q = urllib.parse.urlencode({"filter[identifier]": identifier, "limit": "200"})
        existing = [
            d for d in client.request("GET", f"/bundleIds?{q}").get("data", [])
            if d.get("attributes", {}).get("identifier") == identifier
        ]
        if existing:
            print(f"[ASC] Bundle ID already exists: {identifier}")
            continue
        client.request(
            "POST",
            "/bundleIds",
            {
                "data": {
                    "type": "bundleIds",
                    "attributes": {"identifier": identifier, "name": app_name, "platform": "IOS"},
                }
            },
        )
        print(f"::notice title=Bundle ID registered::{identifier}")


def check_app(client: ASCClient, bundle_id: str) -> int:
    q = urllib.parse.urlencode({"filter[bundleId]": bundle_id})
    apps = [
        a for a in client.request("GET", f"/apps?{q}").get("data", [])
        if a.get("attributes", {}).get("bundleId") == bundle_id
    ]
    if not apps:
        print(
            f"::warning title=App Store Connect App 未创建::尚未在 App Store Connect 找到 {bundle_id} 的 App 记录。"
            "请到 App Store Connect → 我的 App → + 新建 App（iOS，套装 ID 选 app.chimmo，中文名 咩哞），"
            "完成后重新运行工作流即可自动上传 TestFlight。"
        )
        return 2
    attr = apps[0]["attributes"]
    print(f"::notice title=App Store Connect App::{attr.get('name')} ({bundle_id})")
    return 0


def extract_changelog(changelog_path: str, version: str | None = None, build: str | None = None) -> str:
    with open(changelog_path, encoding="utf-8") as f:
        lines = f.read().splitlines()

    sections: list[tuple[str, list[str]]] = []
    cur_ver: str | None = None
    cur_lines: list[str] = []
    for line in lines:
        if line.startswith("## "):
            if cur_ver is not None:
                sections.append((cur_ver, cur_lines))
            cur_ver = line[3:].strip()
            cur_lines = []
        elif cur_ver is not None:
            cur_lines.append(line)
    if cur_ver is not None:
        sections.append((cur_ver, cur_lines))
    if not sections:
        raise ValueError(f"No ## sections found in {changelog_path}")

    chosen_ver, chosen_lines = sections[0]
    if version:
        for sec_ver, sec_lines in sections:
            if sec_ver == version or sec_ver.startswith(version + " "):
                chosen_ver, chosen_lines = sec_ver, sec_lines
                break

    cleaned: list[str] = []
    for raw in chosen_lines:
        s = raw.strip()
        if not s:
            continue
        s = re.sub(r"\*\*(.+?)\*\*", r"\1", s)
        s = re.sub(r"`([^`]+)`", r"\1", s)
        s = "".join(ch for ch in s if unicodedata.category(ch) != "So")
        s = re.sub(r"\s{2,}", " ", s).strip()
        if s.startswith("- "):
            s = "• " + s[2:]
        cleaned.append(s)

    header = f"v{chosen_ver}" + (f" (Build {build})" if build else "")
    text = header + "\n" + "\n".join(cleaned)
    return text[: MAX_WHATS_NEW_CHARS - 1] + "…" if len(text) > MAX_WHATS_NEW_CHARS else text


def sync_whats_new(
    client: ASCClient,
    bundle_id: str,
    build_number: str,
    version: str | None,
    changelog: str,
    locale: str = "zh-Hans",
    timeout_seconds: int = 1200,
) -> None:
    whats_new = extract_changelog(changelog, version=version, build=build_number)
    q = urllib.parse.urlencode({"filter[bundleId]": bundle_id})
    apps = client.request("GET", f"/apps?{q}").get("data", [])
    if not apps:
        raise RuntimeError(f"No app found in App Store Connect for {bundle_id}")
    app_id = apps[0]["id"]

    deadline = time.time() + timeout_seconds
    build_id = None
    while time.time() < deadline:
        params = {"filter[app]": app_id, "filter[version]": build_number, "limit": "5"}
        if version:
            params["filter[preReleaseVersion.version]"] = version
        builds = client.request("GET", f"/builds?{urllib.parse.urlencode(params)}").get("data", [])
        if builds:
            b = builds[0]
            build_id = b["id"]
            state = b.get("attributes", {}).get("processingState", "")
            print(f"[ASC] Build {build_number} state={state}", flush=True)
            if state in ("INVALID", "FAILED"):
                raise RuntimeError(f"Build {build_number} failed processing ({state})")
            if state == "VALID":
                break
        time.sleep(20)

    if not build_id:
        raise RuntimeError(f"Timed out waiting for build {build_number}")

    locs = client.request("GET", f"/builds/{build_id}/betaBuildLocalizations").get("data", [])
    existing = next((x for x in locs if x.get("attributes", {}).get("locale") == locale), None)
    if existing:
        loc_id = existing["id"]
        client.request(
            "PATCH",
            f"/betaBuildLocalizations/{loc_id}",
            {"data": {"type": "betaBuildLocalizations", "id": loc_id, "attributes": {"whatsNew": whats_new}}},
        )
    else:
        client.request(
            "POST",
            "/betaBuildLocalizations",
            {
                "data": {
                    "type": "betaBuildLocalizations",
                    "attributes": {"locale": locale, "whatsNew": whats_new},
                    "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
                }
            },
        )
    print(f"::notice title=TestFlight 测试信息已同步::build {build_number} ({locale})")


def main() -> int:
    ap = argparse.ArgumentParser(description="Chimmo App Store Connect CI helper")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p1 = sub.add_parser("ensure-bundle-ids")
    p1.add_argument("ids", nargs="+")
    p1.add_argument("--name", default="Chimmo")
    p1.add_argument("--key-path", default=None)

    p2 = sub.add_parser("check-app")
    p2.add_argument("bundle_id")
    p2.add_argument("--key-path", default=None)

    p3 = sub.add_parser("sync-whats-new")
    p3.add_argument("--bundle-id", default="app.chimmo")
    p3.add_argument("--build", required=True)
    p3.add_argument("--version", default="")
    p3.add_argument("--changelog", default="CHANGELOG.md")
    p3.add_argument("--locale", default="zh-Hans")
    p3.add_argument("--key-path", default=None)
    p3.add_argument("--timeout", type=int, default=1200)

    args = ap.parse_args()
    key_id = os.environ.get("ASC_KEY_ID", "")
    issuer_id = os.environ.get("ASC_ISSUER_ID", "")
    if not key_id or not issuer_id:
        print("Missing ASC_KEY_ID or ASC_ISSUER_ID", file=sys.stderr)
        return 1

    key_file, tmp = resolve_key_file(args.key_path)
    try:
        client = ASCClient(key_id, issuer_id, key_file)
        if args.cmd == "ensure-bundle-ids":
            ensure_bundle_ids(client, args.ids, app_name=args.name)
            return 0
        if args.cmd == "check-app":
            return check_app(client, args.bundle_id)
        if args.cmd == "sync-whats-new":
            sync_whats_new(
                client,
                bundle_id=args.bundle_id,
                build_number=args.build,
                version=args.version or None,
                changelog=args.changelog,
                locale=args.locale,
                timeout_seconds=args.timeout,
            )
            return 0
    finally:
        if tmp and os.path.exists(tmp):
            os.remove(tmp)
    return 0


if __name__ == "__main__":
    sys.exit(main())
