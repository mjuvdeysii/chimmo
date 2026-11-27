#!/usr/bin/env python3
"""Zero-dependency App Store Connect API helper for Chimmo CI & TestFlight Public Beta.

Uses only Python 3 standard library + `openssl` (preinstalled on macOS/Linux).
Commands:
  python3 Tools/asc.py ensure-bundle-ids app.chimmo
  python3 Tools/asc.py check-app app.chimmo
  python3 Tools/asc.py next-build-number app.chimmo --min 101
  python3 Tools/asc.py sync-whats-new --bundle-id app.chimmo --build 101 --version 2.2.0 --changelog CHANGELOG.md --locales zh-Hans,en-US
  python3 Tools/asc.py sync-beta-metadata --bundle-id app.chimmo --version 2.2.0 [--strict]
  python3 Tools/asc.py prepare-public-beta --bundle-id app.chimmo --build 101 --version 2.2.0 --changelog CHANGELOG.md [--submit-review] [--strict]
  python3 Tools/asc.py audit-beta-readiness app.chimmo [--build 101] [--fail-if-unready]

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (or --key-path).
"""

from __future__ import annotations

import sys

sys.dont_write_bytecode = True

import argparse
import base64
import json
import os
import re
import subprocess
import tempfile
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from typing import Callable

API_BASE = "https://api.appstoreconnect.apple.com/v1"
MAX_WHATS_NEW_CHARS = 4000
RETRYABLE_HTTP_STATUS = {429, 500, 502, 503, 504}
REQUIRED_CONTACT_FIELDS = (
    ("contactFirstName", "BETA_CONTACT_FIRST"),
    ("contactLastName", "BETA_CONTACT_LAST"),
    ("contactEmail", "BETA_CONTACT_EMAIL"),
    ("contactPhone", "BETA_CONTACT_PHONE"),
)
CONTACT_KEYS = tuple(field for field, _ in REQUIRED_CONTACT_FIELDS)
TEAM_CONTACT_KEYS = (*CONTACT_KEYS, "feedbackEmail")

PRIVACY_URL = "https://mjuvdeysii.github.io/chimmo/privacy.html"
SUPPORT_URL = "https://mjuvdeysii.github.io/chimmo/"

PUBLIC_BETA_APP_DESCRIPTIONS = {
    "zh-Hans": (
        "「咩哞（Mie & Mou）」是一款 100% 本机离线的声学共振与室内乐放松应用（纯粹感官艺术体验，非医疗器械，不用于诊断、治疗、治愈或预防任何疾病）。"
        "无需注册账号、不联网、零广告。提供 Delta / Theta / Alpha / Gamma 四大声波频段、"
        "纯干声立体声双耳差频（外放自动切换全频段等时脉动）、零脉冲纯自然声床开关与 0.065 Hz 空间微漂移、动态驻波表盘、"
        "长按蓄力松手即发触发室内乐泛音涟漪、个人轻哼基频调谐、锁屏 Now Playing 媒体控制、"
        "纯黑 OLED 琥珀夜灯盲操、15 秒睡眠渐弱定时与 1080×1350 静态 PNG 明信片离线导出。"
        "收听留意：若有癫痫病史、耳鸣或佩戴助听植入装置，请选用无脉冲自然声床或遵医嘱收听 40 Hz 频段；驾驶及高警觉作业时切勿开启睡前静息或夜灯模式。"
    ),
    "en-US": (
        "Mie & Mou (app.chimmo) is a 100% offline acoustic resonance and chamber music art studio "
        "(sensory art and relaxation only, not a medical device; not intended to diagnose, treat, cure, or prevent any condition). No account, no internet connection, no ads. "
        "Features Delta, Theta, Alpha, and Gamma acoustic beds with dry stereo L/R binaural isolation (plus speaker pulses), a Pure Ambient Wash (No Pulse) mode, "
        "standing-wave visual vessel, press-and-hold harmonic bloom release, offline YIN-vDSP hum tuning, "
        "lock-screen Now Playing transport controls, pure OLED Night Lamp tactile mode, 12 scenes, 28 bilingual chamber works, and 1080x1350 static PNG card export. "
        "Safety Notice: Consult a physician before 40 Hz listening if you have epilepsy, active tinnitus, or a hearing implant; never use sleep or Night Lamp modes while driving."
    ),
}

PUBLIC_BETA_REVIEW_NOTES_TEMPLATE = (
    "Thank you for reviewing Mie & Mou (咩哞, v{version}) for TestFlight External Beta.\n\n"
    "1. Non-Medical Sensory Art Positioning (Guideline 1.4.1):\n"
    "   Mie & Mou is strictly an offline sound-art, focus ambiance, and acoustic relaxation tool. "
    "It is NOT a medical device and makes zero diagnostic, therapeutic, or clinical claims.\n\n"
    "2. Zero Login & 100% Offline Verification:\n"
    "   No sign-in, account, or network access is required. All audio synthesis (AVAudioEngine), CoreHaptics, "
    "lock-screen Now Playing controls, PNG Resonance Card rendering, and on-device pitch detection (pure Swift YIN/vDSP) "
    "run locally in memory without outbound requests.\n\n"
    "3. How to Test Key Features in External Beta:\n"
    "   - Resonance Field Tab (声场, default home): Tap '开启共鸣' / 'Start Resonance' to play/pause; "
    "drag horizontally on the standing-wave dial (1.5-42 Hz) or tap Delta (2.5 Hz) / Theta (6 Hz) / Alpha (10 Hz) / Gamma (40 Hz); "
    "press and hold '按住释怀' / 'Hold Bloom' to release chamber harmonic cascades + CoreHaptics; tap the Wash Drawer icon below to switch sound washes or enable the unmodulated '纯自然声床（零声波脉冲）' / Pure Ambient Wash (No Pulse) toggle.\n"
    "   - OLED Night Lamp Sanctuary (琥珀夜灯暗屏场): Tap the top-right crescent halo icon for pure #000000 black mode featuring relative vertical blind sweep (1.5-42 Hz), quick tap toggle, and 0.65s hold bloom.\n"
    "   - Hum Frequency Matching (轻哼找同频): Tap '轻哼找同频', allow microphone access, hum softly for 2-3 seconds, and tap finish to tune your personal carrier. If denied, 4 vocal root presets (131-256 Hz) work without a microphone.\n"
    "   - Sound Library & Atelier Tabs (声库 / 工坊): Explore 12 circadian scenes, 8 single-tap frisson capsules, all 28 bilingual chamber pieces, 7 ceramic scale members, on-device insights, 1080x1350 PNG card export, and Privacy/Safety disclosures."
)


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _read_der_len(buf: bytes, idx: int) -> tuple[int, int]:
    if idx >= len(buf):
        raise ValueError("Truncated DER length")
    first = buf[idx]
    idx += 1
    if first < 0x80:
        return first, idx
    num_bytes = first & 0x7F
    if num_bytes == 0 or num_bytes > 4 or idx + num_bytes > len(buf):
        raise ValueError("Invalid DER multi-byte length")
    val = int.from_bytes(buf[idx : idx + num_bytes], "big")
    return val, idx + num_bytes


def der_ecdsa_to_raw(der: bytes, size: int = 32) -> bytes:
    if not isinstance(der, (bytes, bytearray)) or len(der) < 8:
        raise ValueError("Invalid DER signature buffer")
    idx = 0
    if der[idx] != 0x30:
        raise ValueError("Invalid DER signature: missing SEQUENCE tag")
    idx += 1
    seq_len, idx = _read_der_len(bytes(der), idx)
    if idx + seq_len > len(der):
        raise ValueError("Invalid DER signature: truncated SEQUENCE")

    parts: list[bytes] = []
    for _ in range(2):
        if idx >= len(der) or der[idx] != 0x02:
            raise ValueError("Invalid DER signature: missing INTEGER tag")
        idx += 1
        nlen, idx = _read_der_len(bytes(der), idx)
        if nlen <= 0 or idx + nlen > len(der):
            raise ValueError("Invalid DER signature: truncated INTEGER value")
        val = bytes(der[idx : idx + nlen])
        idx += nlen
        val = val.lstrip(b"\x00")
        if len(val) > size:
            raise ValueError("ECDSA integer larger than expected curve size")
        parts.append(val.rjust(size, b"\x00"))
    return parts[0] + parts[1]


def make_jwt(key_id: str, issuer_id: str, key_path: str, ttl_seconds: int = 1000) -> str:
    now = int(time.time())
    clamped_ttl = max(120, min(1200, int(ttl_seconds)))
    header = b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}, separators=(",", ":")).encode("utf-8"))
    payload = b64url(
        json.dumps({"iss": issuer_id, "iat": now, "exp": now + clamped_ttl, "aud": "appstoreconnect-v1"}, separators=(",", ":")).encode("utf-8")
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


class ASCHttpError(RuntimeError):
    def __init__(self, method: str, path: str, code: int, detail: str):
        self.method = method
        self.path = path
        self.code = code
        self.detail = detail
        super().__init__(f"ASC {method} {path} failed ({code}): {detail[:500]}")


class ASCClient:
    def __init__(
        self,
        key_id: str,
        issuer_id: str,
        key_path: str,
        max_retries: int = 4,
        sleep_fn: Callable[[float], None] = time.sleep,
        opener: Callable[..., object] = urllib.request.urlopen,
        token_factory: Callable[[str, str, str], str] | None = None,
    ):
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.key_path = key_path
        self.max_retries = max(0, int(max_retries))
        self.sleep_fn = sleep_fn
        self.opener = opener
        self.token_factory = token_factory or (lambda kid, iss, kp: make_jwt(kid, iss, kp))
        self._token = ""
        self._token_exp = 0.0

    def _get_token(self) -> str:
        now = time.time()
        if not self._token or now >= self._token_exp - 60:
            self._token = self.token_factory(self.key_id, self.issuer_id, self.key_path)
            self._token_exp = now + 1000
        return self._token

    @staticmethod
    def _retry_delay_seconds(attempt: int, retry_after_header: str | None = None) -> float:
        if retry_after_header:
            try:
                sec = float(retry_after_header.strip())
                if sec > 0:
                    return min(30.0, max(1.0, sec))
            except ValueError:
                pass
        return min(30.0, 1.5 * (2**attempt))

    def request(self, method: str, path: str, body: dict | None = None) -> dict:
        url = path if path.startswith("http") else f"{API_BASE}{path}"
        data = json.dumps(body).encode("utf-8") if body is not None else None
        refreshed_auth = False

        for attempt in range(self.max_retries + 1):
            req = urllib.request.Request(url, data=data, method=method)
            req.add_header("Authorization", f"Bearer {self._get_token()}")
            req.add_header("Accept", "application/json")
            if data is not None:
                req.add_header("Content-Type", "application/json")
            try:
                with self.opener(req, timeout=30) as resp:  # type: ignore[arg-type]
                    raw = resp.read()
                    return json.loads(raw.decode("utf-8")) if raw else {}
            except urllib.error.HTTPError as e:
                detail = e.read().decode("utf-8", errors="replace")
                if e.code == 401 and not refreshed_auth:
                    refreshed_auth = True
                    self._token = ""
                    self._token_exp = 0.0
                    continue
                if e.code in RETRYABLE_HTTP_STATUS and attempt < self.max_retries:
                    retry_after = e.headers.get("Retry-After") if getattr(e, "headers", None) else None
                    self.sleep_fn(self._retry_delay_seconds(attempt, retry_after))
                    continue
                raise ASCHttpError(method, path, e.code, detail) from e
            except (urllib.error.URLError, TimeoutError, OSError):
                if attempt < self.max_retries:
                    self.sleep_fn(self._retry_delay_seconds(attempt))
                    continue
                raise
        raise RuntimeError(f"Unreachable retry loop termination for {method} {path}")


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


def find_app(client: ASCClient, bundle_id: str) -> dict | None:
    q = urllib.parse.urlencode({"filter[bundleId]": bundle_id})
    apps = [
        a for a in client.request("GET", f"/apps?{q}").get("data", [])
        if a.get("attributes", {}).get("bundleId") == bundle_id
    ]
    return apps[0] if apps else None


def next_build_number(client: ASCClient, bundle_id: str, min_build: int = 101) -> int:
    app = find_app(client, bundle_id)
    highest = 0
    if app:
        q = urllib.parse.urlencode({"filter[app]": app["id"], "limit": "50", "sort": "-uploadedDate"})
        builds = client.request("GET", f"/builds?{q}").get("data", [])
        for b in builds:
            raw_ver = str(b.get("attributes", {}).get("version", "")).strip()
            if raw_ver.isdigit():
                highest = max(highest, int(raw_ver))
    return max(int(min_build), highest + 1)


def wait_for_valid_build(
    client: ASCClient,
    app_id: str,
    build_number: str,
    version: str | None,
    timeout_seconds: int = 1200,
    sleep_fn: Callable[[float], None] = time.sleep,
) -> str:
    deadline = time.time() + timeout_seconds
    while True:
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
                return build_id
        if time.time() >= deadline:
            break
        sleep_fn(20)
    raise RuntimeError(f"Timed out waiting for build {build_number} to become VALID")


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
    app = find_app(client, bundle_id)
    if not app:
        print(
            f"::warning title=App Store Connect App 未创建::尚未在 App Store Connect 找到 {bundle_id} 的 App 记录。"
            "请到 App Store Connect -> 我的 App -> + 新建 App（iOS，套装 ID 选 app.chimmo，中文名 咩哞），"
            "完成后重新运行工作流即可自动上传 TestFlight。"
        )
        return 2
    attr = app["attributes"]
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
        s = re.sub(r"\[([^\]]+)\]\([^\)]+\)", r"\1", s)
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


def build_zh_whats_new(version: str | None = None, build: str | None = None) -> str:
    ver = version or "2.2.0"
    b = f" (Build {build})" if build else ""
    text = (
        f"v{ver}{b}\n"
        "• 精炼三页一体的「声场 / 声库 / 工坊」窑陶棉纸交互，全量支持中英文双语\n"
        "• 双声总线独立渲染，保证纯干声立体声双耳差频不串音，并新增「纯自然声床（零声波脉冲）」开关\n"
        "• 全量 28 首公版与原创室内乐曲谱中英双语检索、1.5–42 Hz 纯黑夜灯盲操与 15 秒睡眠定时暂停续接\n"
        "• 本机离线 YIN-vDSP 轻哼调频、锁屏 Now Playing 控制与 1080×1350 静态 PNG 共振明信片导出"
    )
    return text[: MAX_WHATS_NEW_CHARS - 1] + "…" if len(text) > MAX_WHATS_NEW_CHARS else text


def build_en_whats_new(version: str | None = None, build: str | None = None) -> str:
    ver = version or "2.2.0"
    b = f" (Build {build})" if build else ""
    text = (
        f"v{ver}{b}\n"
        "- Refined 3-tab kiln-ceramic architecture (Resonance Field / Sound Library / Atelier) with full zh-Hans & en localization\n"
        "- Dual-bus DSP audio graph for dry L/R stereo binaural isolation, speaker pulses, and a Pure Ambient Wash (No Pulse) mode\n"
        "- Full bilingual 28-piece classical & original chamber library, OLED #000000 Night Lamp sweep (1.5-42 Hz), and offline YIN-vDSP hum tuning\n"
        "- 15-second monotonic sleep timer pause/resume fade, Lock Screen Now Playing controls, and 1080x1350 static PNG card export"
    )
    return text[: MAX_WHATS_NEW_CHARS - 1] + "…" if len(text) > MAX_WHATS_NEW_CHARS else text


def _whats_new_for_locale(locale: str, changelog: str, version: str | None, build: str | None) -> str:
    if locale.lower().startswith("en"):
        return build_en_whats_new(version=version, build=build)
    if locale.lower().startswith("zh"):
        return build_zh_whats_new(version=version, build=build)
    return extract_changelog(changelog, version=version, build=build)


def upsert_beta_build_localization(
    client: ASCClient,
    build_id: str,
    locale: str,
    whats_new: str,
    existing_locs: list[dict] | None = None,
) -> None:
    locs = existing_locs if existing_locs is not None else client.request("GET", f"/builds/{build_id}/betaBuildLocalizations").get("data", [])
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


def sync_whats_new(
    client: ASCClient,
    bundle_id: str,
    build_number: str,
    version: str | None,
    changelog: str,
    locale: str = "zh-Hans",
    locales: list[str] | None = None,
    timeout_seconds: int = 1200,
) -> None:
    target_locales: list[str] = []
    for raw in (locales if locales is not None else [locale]):
        item = raw.strip()
        if item and item not in target_locales:
            target_locales.append(item)
    if not target_locales:
        target_locales = ["zh-Hans"]

    app = find_app(client, bundle_id)
    if not app:
        raise RuntimeError(f"No app found in App Store Connect for {bundle_id}")
    build_id = wait_for_valid_build(client, app["id"], build_number, version, timeout_seconds=timeout_seconds)
    existing_locs = client.request("GET", f"/builds/{build_id}/betaBuildLocalizations").get("data", [])
    for loc in target_locales:
        whats_new = _whats_new_for_locale(loc, changelog=changelog, version=version, build=build_number)
        upsert_beta_build_localization(client, build_id, locale=loc, whats_new=whats_new, existing_locs=existing_locs)
        print(f"::notice title=TestFlight 测试信息已同步::build {build_number} ({loc})")


def fetch_team_fallback_contacts(client: ASCClient, exclude_app_id: str) -> dict[str, str]:
    found: dict[str, str] = {}
    apps = client.request("GET", "/apps?limit=50").get("data", []) or []

    def have_review_contacts() -> bool:
        return all(bool(found.get(k)) for k in CONTACT_KEYS)

    def have_all() -> bool:
        return all(bool(found.get(k)) for k in TEAM_CONTACT_KEYS)

    def absorb_attrs(attrs: dict | None, keys: tuple[str, ...]) -> None:
        if not isinstance(attrs, dict):
            return
        for k in keys:
            if not found.get(k):
                val = str(attrs.get(k) or "").strip()
                if val:
                    found[k] = val

    for app in apps:
        other_id = str(app.get("id") or "").strip()
        if not other_id or other_id == exclude_app_id:
            continue

        try:
            rev_resp = client.request("GET", f"/apps/{other_id}/betaAppReviewDetail")
            rev_attrs = (rev_resp.get("data") or {}).get("attributes", {})
            absorb_attrs(rev_attrs, CONTACT_KEYS)
        except ASCHttpError:
            pass

        if not have_review_contacts():
            try:
                ver_resp = client.request(
                    "GET",
                    f"/apps/{other_id}/appStoreVersions?limit=5&include=appStoreReviewDetail",
                )
                for inc in ver_resp.get("included", []) or []:
                    if inc.get("type") == "appStoreReviewDetails":
                        absorb_attrs(inc.get("attributes", {}), CONTACT_KEYS)
            except ASCHttpError:
                pass

        if not found.get("feedbackEmail"):
            try:
                loc_resp = client.request("GET", f"/apps/{other_id}/betaAppLocalizations")
                for loc in loc_resp.get("data", []) or []:
                    fb = str((loc.get("attributes") or {}).get("feedbackEmail") or "").strip()
                    if fb:
                        found["feedbackEmail"] = fb
                        break
            except ASCHttpError:
                pass

        if have_all():
            break

    if any(found.values()):
        print(
            "[ASC] Team fallback contacts discovered ("
            f"first={bool(found.get('contactFirstName'))}, "
            f"last={bool(found.get('contactLastName'))}, "
            f"email={bool(found.get('contactEmail'))}, "
            f"phone={bool(found.get('contactPhone'))}, "
            f"feedbackEmail={bool(found.get('feedbackEmail'))})"
        )
    return found


def _resolve_team_fallbacks(
    client: ASCClient,
    app_id: str,
    feedback_email: str,
    contact_first: str,
    contact_last: str,
    contact_email: str,
    contact_phone: str,
    inherit_team_contacts: bool = True,
) -> tuple[str, dict[str, str]]:
    explicit_fb = feedback_email.strip()
    explicit_contacts = {
        "contactFirstName": contact_first.strip(),
        "contactLastName": contact_last.strip(),
        "contactEmail": contact_email.strip(),
        "contactPhone": contact_phone.strip(),
    }

    target_fb = ""
    target_contacts: dict[str, str] = {}
    need_discovery = not explicit_fb or any(not v for v in explicit_contacts.values())
    if inherit_team_contacts and need_discovery:
        try:
            locs = client.request("GET", f"/apps/{app_id}/betaAppLocalizations").get("data", []) or []
            for loc in locs:
                val = str((loc.get("attributes") or {}).get("feedbackEmail") or "").strip()
                if val:
                    target_fb = val
                    break
        except ASCHttpError:
            pass
        try:
            detail = client.request("GET", f"/apps/{app_id}/betaAppReviewDetail").get("data") or {}
            attrs = detail.get("attributes", {}) or {}
            for k in CONTACT_KEYS:
                val = str(attrs.get(k) or "").strip()
                if val:
                    target_contacts[k] = val
        except ASCHttpError:
            pass

    have_all_without_team = bool(explicit_fb or target_fb) and all(
        bool(explicit_contacts[k] or target_contacts.get(k)) for k in CONTACT_KEYS
    )

    team_contacts: dict[str, str] = {}
    if inherit_team_contacts and need_discovery and not have_all_without_team:
        team_contacts = fetch_team_fallback_contacts(client, exclude_app_id=app_id)

    fallback_fb = (
        str(team_contacts.get("feedbackEmail") or "").strip()
        or explicit_contacts["contactEmail"]
        or target_contacts.get("contactEmail", "")
        or str(team_contacts.get("contactEmail") or "").strip()
    )
    fallback_contacts: dict[str, str] = {k: str(team_contacts.get(k) or "").strip() for k in CONTACT_KEYS}
    if not fallback_contacts["contactEmail"]:
        fallback_contacts["contactEmail"] = (
            explicit_fb
            or target_fb
            or str(team_contacts.get("feedbackEmail") or "").strip()
        )
    return fallback_fb, fallback_contacts


def sync_beta_app_localizations(
    client: ASCClient,
    app_id: str,
    feedback_email: str = "",
    strict: bool = False,
    fallback_feedback_email: str = "",
) -> dict[str, str]:
    existing_locs = client.request("GET", f"/apps/{app_id}/betaAppLocalizations").get("data", [])
    email_status: dict[str, str] = {}
    for locale, description in PUBLIC_BETA_APP_DESCRIPTIONS.items():
        existing = next((x for x in existing_locs if x.get("attributes", {}).get("locale") == locale), None)
        existing_attr = (existing or {}).get("attributes", {})
        resolved_email = (
            feedback_email.strip()
            or str(existing_attr.get("feedbackEmail") or "").strip()
            or fallback_feedback_email.strip()
        )

        attrs: dict[str, str] = {
            "description": description,
            "marketingUrl": SUPPORT_URL,
            "privacyPolicyUrl": PRIVACY_URL,
        }
        if resolved_email:
            attrs["feedbackEmail"] = resolved_email

        email_status[locale] = resolved_email
        if existing:
            loc_id = existing["id"]
            if not resolved_email and not str(existing_attr.get("feedbackEmail") or "").strip():
                msg = (
                    f"betaAppLocalization ({locale}) is missing required feedbackEmail "
                    "(set GitHub Secret BETA_FEEDBACK_EMAIL or fill Feedback Email in App Store Connect)."
                )
                print(f"::warning title=BetaAppLocalization ({locale}) Missing Feedback Email::{msg}")
                if strict:
                    raise RuntimeError(msg)
            try:
                client.request(
                    "PATCH",
                    f"/betaAppLocalizations/{loc_id}",
                    {"data": {"type": "betaAppLocalizations", "id": loc_id, "attributes": attrs}},
                )
                print(f"[ASC] Synced betaAppLocalization ({locale})")
            except ASCHttpError as e:
                if strict:
                    raise
                print(f"::warning title=BetaAppLocalization ({locale}) Skipped::{e.code} {e.detail[:220]}")
        else:
            if not resolved_email:
                msg = (
                    f"Cannot create betaAppLocalization ({locale}) without feedbackEmail "
                    "(set GitHub Secret BETA_FEEDBACK_EMAIL)."
                )
                print(f"::warning title=BetaAppLocalization ({locale}) Skipped::{msg}")
                if strict:
                    raise RuntimeError(msg)
                continue
            attrs["locale"] = locale
            try:
                client.request(
                    "POST",
                    "/betaAppLocalizations",
                    {
                        "data": {
                            "type": "betaAppLocalizations",
                            "attributes": attrs,
                            "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                        }
                    },
                )
                print(f"[ASC] Synced betaAppLocalization ({locale})")
            except ASCHttpError as e:
                if strict:
                    raise
                print(f"::warning title=BetaAppLocalization ({locale}) Skipped::{e.code} {e.detail[:220]}")
    return email_status


def sync_beta_review_details(
    client: ASCClient,
    app_id: str,
    version: str = "2.2.0",
    contact_first: str = "",
    contact_last: str = "",
    contact_email: str = "",
    contact_phone: str = "",
    strict: bool = False,
    fallback_contacts: dict[str, str] | None = None,
) -> dict:
    try:
        resp = client.request("GET", f"/apps/{app_id}/betaAppReviewDetail")
        detail = resp.get("data")
    except ASCHttpError as e:
        if e.code == 404:
            detail = None
        else:
            raise

    existing_attrs = (detail or {}).get("attributes", {}) or {}
    cli_values = {
        "contactFirstName": contact_first.strip(),
        "contactLastName": contact_last.strip(),
        "contactEmail": contact_email.strip(),
        "contactPhone": contact_phone.strip(),
    }
    fb_map = fallback_contacts or {}

    merged_contacts: dict[str, str] = {}
    missing_secrets: list[str] = []
    for field_name, secret_name in REQUIRED_CONTACT_FIELDS:
        val = (
            cli_values[field_name]
            or str(existing_attrs.get(field_name) or "").strip()
            or str(fb_map.get(field_name) or "").strip()
        )
        if val:
            merged_contacts[field_name] = val
        else:
            missing_secrets.append(f"{field_name} ({secret_name})")

    if missing_secrets:
        msg = (
            "Missing required TestFlight external review contact fields: "
            + ", ".join(missing_secrets)
            + ". Populate the matching GitHub Actions Secrets or App Store Connect -> TestFlight -> Test Information before external submission."
        )
        print(f"::warning title=TestFlight Review Contact Incomplete::{msg}")
        if strict:
            raise RuntimeError(msg)
        return detail or {}

    if not detail or not detail.get("id"):
        msg = "betaAppReviewDetails resource ID not returned by App Store Connect."
        print(f"::warning title=TestFlight Review Contact Missing::{msg}")
        if strict:
            raise RuntimeError(msg)
        return {}

    attrs: dict[str, object] = {
        "demoAccountRequired": False,
        "notes": PUBLIC_BETA_REVIEW_NOTES_TEMPLATE.format(version=version or "2.2.0"),
        **merged_contacts,
    }
    did = detail["id"]
    try:
        updated = client.request(
            "PATCH",
            f"/betaAppReviewDetails/{did}",
            {"data": {"type": "betaAppReviewDetails", "id": did, "attributes": attrs}},
        )
        print("[ASC] Updated betaAppReviewDetails")
        return updated.get("data", detail)
    except ASCHttpError as e:
        if strict:
            raise
        print(f"::warning title=TestFlight Review Details Skipped::{e.code} {e.detail[:220]}")
        return detail


def sync_beta_metadata(
    client: ASCClient,
    bundle_id: str,
    version: str = "2.2.0",
    feedback_email: str = "",
    contact_first: str = "",
    contact_last: str = "",
    contact_email: str = "",
    contact_phone: str = "",
    inherit_team_contacts: bool = True,
    strict: bool = False,
) -> None:
    app = find_app(client, bundle_id)
    if not app:
        raise RuntimeError(f"No app found in App Store Connect for {bundle_id}")
    app_id = app["id"]
    fallback_fb, fallback_contacts = _resolve_team_fallbacks(
        client,
        app_id=app_id,
        feedback_email=feedback_email,
        contact_first=contact_first,
        contact_last=contact_last,
        contact_email=contact_email,
        contact_phone=contact_phone,
        inherit_team_contacts=inherit_team_contacts,
    )
    sync_beta_app_localizations(
        client,
        app_id,
        feedback_email=feedback_email,
        strict=strict,
        fallback_feedback_email=fallback_fb,
    )
    sync_beta_review_details(
        client,
        app_id,
        version=version or "2.2.0",
        contact_first=contact_first,
        contact_last=contact_last,
        contact_email=contact_email,
        contact_phone=contact_phone,
        strict=strict,
        fallback_contacts=fallback_contacts,
    )


def ensure_external_beta_group(
    client: ASCClient,
    app_id: str,
    group_name: str,
    public_link: bool,
    build_id: str,
) -> str:
    groups = client.request("GET", f"/apps/{app_id}/betaGroups?limit=200").get("data", [])
    external = next(
        (
            g for g in groups
            if not g.get("attributes", {}).get("isInternalGroup", False)
            and g.get("attributes", {}).get("name") == group_name
        ),
        None,
    )
    if not external:
        created = client.request(
            "POST",
            "/betaGroups",
            {
                "data": {
                    "type": "betaGroups",
                    "attributes": {
                        "name": group_name,
                        "isInternalGroup": False,
                    },
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )
        external = created["data"]
        print(f"[ASC] Created external beta group '{group_name}'")

    group_id = external["id"]
    try:
        client.request(
            "POST",
            f"/betaGroups/{group_id}/relationships/builds",
            {"data": [{"type": "builds", "id": build_id}]},
        )
        print(f"[ASC] Associated build {build_id} with external group '{group_name}'")
    except ASCHttpError as e:
        print(f"::warning title=External Beta Group Build Link::{e.code} {e.detail[:220]}")

    if public_link and not external.get("attributes", {}).get("publicLinkEnabled", False):
        try:
            res = client.request(
                "PATCH",
                f"/betaGroups/{group_id}",
                {"data": {"type": "betaGroups", "id": group_id, "attributes": {"publicLinkEnabled": True}}},
            )
            link_url = res.get("data", {}).get("attributes", {}).get("publicLink", "")
            if link_url:
                print(f"::notice title=TestFlight Public Link::{link_url}")
        except ASCHttpError as e:
            print(f"::warning title=TestFlight Public Link Pending::将在公测审核通过后可开启公开链接 ({e.code})")
    return group_id


def submit_beta_review(client: ASCClient, build_id: str, strict: bool = False) -> None:
    try:
        existing = client.request("GET", f"/builds/{build_id}/betaAppReviewSubmission").get("data")
        if existing:
            state = existing.get("attributes", {}).get("betaReviewState", "")
            print(f"::notice title=TestFlight Beta Review::{build_id} already state={state}")
            return
    except ASCHttpError as e:
        if e.code != 404:
            raise

    try:
        res = client.request(
            "POST",
            "/betaAppReviewSubmissions",
            {
                "data": {
                    "type": "betaAppReviewSubmissions",
                    "relationships": {"build": {"data": {"type": "builds", "id": build_id}}},
                }
            },
        )
        state = res.get("data", {}).get("attributes", {}).get("betaReviewState", "WAITING_FOR_REVIEW")
        print(f"::notice title=TestFlight 公测审核已提交::state={state}")
    except ASCHttpError as e:
        msg = (
            f"TestFlight external beta submission rejected by App Store Connect ({e.code}): {e.detail[:260]}. "
            "Verify BETA_FEEDBACK_EMAIL, BETA_CONTACT_FIRST/LAST/EMAIL/PHONE, and App Privacy Policy URL."
        )
        if strict:
            raise RuntimeError(msg) from e
        print(f"::warning title=TestFlight 公测提审需要补齐联系信息::{msg}")


def prepare_public_beta(
    client: ASCClient,
    bundle_id: str,
    build_number: str,
    version: str | None,
    changelog: str,
    group_name: str,
    public_link: bool,
    submit_review: bool,
    feedback_email: str,
    contact_first: str,
    contact_last: str,
    contact_email: str,
    contact_phone: str,
    timeout_seconds: int,
    strict: bool = False,
    inherit_team_contacts: bool = True,
) -> None:
    app = find_app(client, bundle_id)
    if not app:
        raise RuntimeError(f"No app found in App Store Connect for {bundle_id}")
    app_id = app["id"]
    build_id = wait_for_valid_build(client, app_id, build_number, version, timeout_seconds=timeout_seconds)

    existing_locs = client.request("GET", f"/builds/{build_id}/betaBuildLocalizations").get("data", [])
    upsert_beta_build_localization(
        client,
        build_id,
        locale="zh-Hans",
        whats_new=build_zh_whats_new(version=version, build=build_number),
        existing_locs=existing_locs,
    )
    upsert_beta_build_localization(
        client,
        build_id,
        locale="en-US",
        whats_new=build_en_whats_new(version=version, build=build_number),
        existing_locs=existing_locs,
    )

    fallback_fb, fallback_contacts = _resolve_team_fallbacks(
        client,
        app_id=app_id,
        feedback_email=feedback_email,
        contact_first=contact_first,
        contact_last=contact_last,
        contact_email=contact_email,
        contact_phone=contact_phone,
        inherit_team_contacts=inherit_team_contacts,
    )
    sync_beta_app_localizations(
        client,
        app_id,
        feedback_email=feedback_email,
        strict=strict,
        fallback_feedback_email=fallback_fb,
    )
    sync_beta_review_details(
        client,
        app_id,
        version=version or "2.2.0",
        contact_first=contact_first,
        contact_last=contact_last,
        contact_email=contact_email,
        contact_phone=contact_phone,
        strict=strict,
        fallback_contacts=fallback_contacts,
    )
    ensure_external_beta_group(
        client,
        app_id,
        group_name=group_name,
        public_link=public_link,
        build_id=build_id,
    )
    if submit_review:
        submit_beta_review(client, build_id, strict=strict)


def audit_beta_readiness(
    client: ASCClient,
    bundle_id: str,
    build_number: str = "",
    fail_if_unready: bool = False,
) -> int:
    app = find_app(client, bundle_id)
    if not app:
        print(f"[AUDIT] App NOT found for {bundle_id}")
        return 2
    app_id = app["id"]
    app_name = str(app.get("attributes", {}).get("name") or "")
    print(f"[AUDIT] App: {app_name} ({bundle_id}, id={app_id})")

    missing_blockers: list[str] = []
    if app_name not in {"咩哞", "Mie & Mou", "咩哞 · Mie & Mou"}:
        print(
            f"::warning title=ASC App Name Drift::Current ASC App Name is '{app_name}', "
            "consider updating it to '咩哞' (zh-Hans) / 'Mie & Mou' (en-US) in App Store Connect."
        )

    locs = client.request("GET", f"/apps/{app_id}/betaAppLocalizations").get("data", [])
    loc_by_code = {str(l.get("attributes", {}).get("locale") or ""): l.get("attributes", {}) for l in locs}
    print(f"[AUDIT] BetaAppLocalizations: {sorted(loc_by_code.keys())}")
    for req_loc in ("zh-Hans", "en-US"):
        a = loc_by_code.get(req_loc)
        if not a:
            missing_blockers.append(f"betaAppLocalization({req_loc})")
            continue
        has_email = bool(str(a.get("feedbackEmail") or "").strip())
        has_privacy = bool(str(a.get("privacyPolicyUrl") or "").strip())
        has_desc = bool(str(a.get("description") or "").strip())
        print(
            f"  - {req_loc}: feedbackEmail={'YES' if has_email else 'MISSING'}, "
            f"privacyUrl={'YES' if has_privacy else 'MISSING'}, description={'YES' if has_desc else 'MISSING'}"
        )
        if not has_email:
            missing_blockers.append(f"feedbackEmail({req_loc})")
        if not has_privacy:
            missing_blockers.append(f"privacyPolicyUrl({req_loc})")
        if not has_desc:
            missing_blockers.append(f"description({req_loc})")

    try:
        detail = client.request("GET", f"/apps/{app_id}/betaAppReviewDetail").get("data", {}) or {}
        da = detail.get("attributes", {})
        print(
            f"[AUDIT] ReviewDetails: first={bool(da.get('contactFirstName'))}, "
            f"last={bool(da.get('contactLastName'))}, "
            f"email={bool(da.get('contactEmail'))}, "
            f"phone={bool(da.get('contactPhone'))}, "
            f"notes={bool(da.get('notes'))}"
        )
        for field_name, secret_name in REQUIRED_CONTACT_FIELDS:
            if not str(da.get(field_name) or "").strip():
                missing_blockers.append(f"{field_name}[{secret_name}]")
        if not str(da.get("notes") or "").strip():
            missing_blockers.append("reviewNotes")
    except ASCHttpError as e:
        print(f"[AUDIT] ReviewDetails fetch error ({e.code})")
        missing_blockers.append(f"betaAppReviewDetail(HTTP {e.code})")

    groups = client.request("GET", f"/apps/{app_id}/betaGroups?limit=200").get("data", [])
    ext_groups = [g for g in groups if not g.get("attributes", {}).get("isInternalGroup", False)]
    print(
        f"[AUDIT] External BetaGroups ({len(ext_groups)}): "
        + ", ".join(
            f"{g.get('attributes', {}).get('name')}(enabled={g.get('attributes', {}).get('publicLinkEnabled')}, publicLink={g.get('attributes', {}).get('publicLink') or 'off'})"
            for g in ext_groups
        )
    )
    if not ext_groups:
        missing_blockers.append("externalBetaGroup")

    try:
        params = {"filter[app]": app_id, "limit": "5", "sort": "-uploadedDate"}
        if build_number.strip():
            params["filter[version]"] = build_number.strip()
        builds = client.request("GET", f"/builds?{urllib.parse.urlencode(params)}").get("data", [])
        if builds:
            b = builds[0]
            b_ver = b.get("attributes", {}).get("version", "")
            b_state = b.get("attributes", {}).get("processingState", "")
            b_enc = b.get("attributes", {}).get("usesNonExemptEncryption")
            if b_state != "VALID":
                missing_blockers.append(f"buildState({b_state})")

            b_locs = client.request("GET", f"/builds/{b['id']}/betaBuildLocalizations").get("data", [])
            b_loc_codes = {str(x.get("attributes", {}).get("locale") or "") for x in b_locs if str(x.get("attributes", {}).get("whatsNew") or "").strip()}
            for req_loc in ("zh-Hans", "en-US"):
                if req_loc not in b_loc_codes:
                    missing_blockers.append(f"buildWhatsNew({req_loc})")

            review_state = "NOT_SUBMITTED"
            try:
                sub = client.request("GET", f"/builds/{b['id']}/betaAppReviewSubmission").get("data")
                if sub:
                    review_state = sub.get("attributes", {}).get("betaReviewState", "UNKNOWN")
            except ASCHttpError as se:
                if se.code != 404:
                    review_state = f"ERR_{se.code}"
            print(
                f"[AUDIT] TargetBuild: build={b_ver}, processingState={b_state}, "
                f"usesNonExemptEncryption={b_enc}, whatsNew={sorted(b_loc_codes)}, betaReviewState={review_state}"
            )
        else:
            missing_blockers.append("targetBuildNotFound")
    except ASCHttpError as e:
        print(f"[AUDIT] LatestBuild fetch error ({e.code})")
        missing_blockers.append(f"latestBuild(HTTP {e.code})")

    if missing_blockers:
        print(f"[AUDIT] Readiness: BLOCKED ({', '.join(missing_blockers)})")
        return 3 if fail_if_unready else 0

    print("[AUDIT] Readiness: READY_FOR_PUBLIC_BETA")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Chimmo App Store Connect CI & Public Beta helper")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p1 = sub.add_parser("ensure-bundle-ids")
    p1.add_argument("ids", nargs="+")
    p1.add_argument("--name", default="Chimmo")
    p1.add_argument("--key-path", default=None)

    p2 = sub.add_parser("check-app")
    p2.add_argument("bundle_id")
    p2.add_argument("--key-path", default=None)

    p_next = sub.add_parser("next-build-number")
    p_next.add_argument("bundle_id")
    p_next.add_argument("--min", type=int, default=101, dest="min_build")
    p_next.add_argument("--key-path", default=None)

    p3 = sub.add_parser("sync-whats-new")
    p3.add_argument("--bundle-id", default="app.chimmo")
    p3.add_argument("--build", required=True)
    p3.add_argument("--version", default="")
    p3.add_argument("--changelog", default="CHANGELOG.md")
    p3.add_argument("--locale", default="zh-Hans")
    p3.add_argument("--locales", default="", help="Comma-separated locales synced in a single build poll (e.g. zh-Hans,en-US)")
    p3.add_argument("--key-path", default=None)
    p3.add_argument("--timeout", type=int, default=1200)

    p4 = sub.add_parser("prepare-public-beta")
    p4.add_argument("--bundle-id", default="app.chimmo")
    p4.add_argument("--build", required=True)
    p4.add_argument("--version", default="2.2.0")
    p4.add_argument("--changelog", default="CHANGELOG.md")
    p4.add_argument("--group-name", default="公测")
    p4.add_argument("--public-link", action="store_true")
    p4.add_argument("--submit-review", action="store_true")
    p4.add_argument("--strict", action="store_true", help="Fail non-zero if feedbackEmail, contacts, or submission fails")
    p4.add_argument("--no-inherit-team-contacts", action="store_true", help="Disable inheriting missing contacts from other team apps")
    p4.add_argument("--feedback-email", default="")
    p4.add_argument("--contact-first", default="")
    p4.add_argument("--contact-last", default="")
    p4.add_argument("--contact-email", default="")
    p4.add_argument("--contact-phone", default="")
    p4.add_argument("--key-path", default=None)
    p4.add_argument("--timeout", type=int, default=1200)

    p_meta = sub.add_parser("sync-beta-metadata")
    p_meta.add_argument("--bundle-id", default="app.chimmo")
    p_meta.add_argument("--version", default="2.2.0")
    p_meta.add_argument("--strict", action="store_true", help="Fail non-zero if feedbackEmail or contact fields are incomplete")
    p_meta.add_argument("--no-inherit-team-contacts", action="store_true", help="Disable inheriting missing contacts from other team apps")
    p_meta.add_argument("--feedback-email", default="")
    p_meta.add_argument("--contact-first", default="")
    p_meta.add_argument("--contact-last", default="")
    p_meta.add_argument("--contact-email", default="")
    p_meta.add_argument("--contact-phone", default="")
    p_meta.add_argument("--key-path", default=None)

    p5 = sub.add_parser("audit-beta-readiness")
    p5.add_argument("bundle_id")
    p5.add_argument("--build", default="")
    p5.add_argument("--fail-if-unready", action="store_true")
    p5.add_argument("--key-path", default=None)

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
        if args.cmd == "next-build-number":
            print(next_build_number(client, args.bundle_id, min_build=args.min_build))
            return 0
        if args.cmd == "sync-whats-new":
            parsed_locales = [s.strip() for s in args.locales.split(",") if s.strip()] if args.locales.strip() else None
            sync_whats_new(
                client,
                bundle_id=args.bundle_id,
                build_number=args.build,
                version=args.version or None,
                changelog=args.changelog,
                locale=args.locale,
                locales=parsed_locales,
                timeout_seconds=args.timeout,
            )
            return 0
        if args.cmd == "prepare-public-beta":
            prepare_public_beta(
                client,
                bundle_id=args.bundle_id,
                build_number=args.build,
                version=args.version or None,
                changelog=args.changelog,
                group_name=args.group_name,
                public_link=args.public_link,
                submit_review=args.submit_review,
                feedback_email=args.feedback_email,
                contact_first=args.contact_first,
                contact_last=args.contact_last,
                contact_email=args.contact_email,
                contact_phone=args.contact_phone,
                timeout_seconds=args.timeout,
                strict=args.strict,
                inherit_team_contacts=not args.no_inherit_team_contacts,
            )
            return 0
        if args.cmd == "sync-beta-metadata":
            sync_beta_metadata(
                client,
                bundle_id=args.bundle_id,
                version=args.version or "2.2.0",
                feedback_email=args.feedback_email,
                contact_first=args.contact_first,
                contact_last=args.contact_last,
                contact_email=args.contact_email,
                contact_phone=args.contact_phone,
                inherit_team_contacts=not args.no_inherit_team_contacts,
                strict=args.strict,
            )
            return 0
        if args.cmd == "audit-beta-readiness":
            return audit_beta_readiness(
                client,
                args.bundle_id,
                build_number=args.build,
                fail_if_unready=args.fail_if_unready,
            )
    finally:
        if tmp and os.path.exists(tmp):
            os.remove(tmp)
    return 0


if __name__ == "__main__":
    sys.exit(main())
