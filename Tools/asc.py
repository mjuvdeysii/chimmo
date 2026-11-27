#!/usr/bin/env python3
"""Zero-dependency App Store Connect API helper for Chimmo CI & TestFlight Public Beta.

Uses only Python 3 standard library + `openssl` (preinstalled on macOS/Linux).
Commands:
  python3 Tools/asc.py ensure-bundle-ids app.chimmo
  python3 Tools/asc.py check-app app.chimmo
  python3 Tools/asc.py sync-whats-new --bundle-id app.chimmo --build 101 --version 2.2.0 --changelog CHANGELOG.md --locale zh-Hans
  python3 Tools/asc.py prepare-public-beta --bundle-id app.chimmo --build 101 --version 2.2.0 --changelog CHANGELOG.md [--submit-review]
  python3 Tools/asc.py audit-beta-readiness app.chimmo

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
    "   - Resonance Field Tab (声场, default home): Tap '开启共鸣' to start/pause waves; drag vertically on the standing-wave dial "
    "or switch Delta (2.5 Hz) / Theta (6 Hz) / Alpha (10 Hz) / Gamma (40 Hz) pills; press & hold '按住释怀' "
    "to trigger chamber harmonic cascades + CoreHaptics; tap the Night Lamp moon icon for pure OLED #000000 blind sweep mode; "
    "tap the card seal icon to render & save/share a 1080x1350 PNG card.\n"
    "   - Hum Frequency Matching (轻哼找同频): Tap '轻哼找同频', allow microphone access, hum softly for 2-3 seconds, "
    "and tap finish to tune your personal carrier. If microphone access is denied, 4 preset vocal roots (131-256 Hz) remain usable.\n"
    "   - Sound Library Tab (声库): Browse circadian presets, single-tap 8 acoustic frisson capsules, or push into the 28-piece chamber archive.\n"
    "   - Kiln Atelier Tab (工坊): Inspect on-device listening history, toggle Day/Night/Auto themes & tactile haptics, "
    "audition the 7 ceramic scale members, and read Acoustic Safety (including 40 Hz guidance) and Privacy disclosures."
)


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


class ASCHttpError(RuntimeError):
    def __init__(self, method: str, path: str, code: int, detail: str):
        self.method = method
        self.path = path
        self.code = code
        self.detail = detail
        super().__init__(f"ASC {method} {path} failed ({code}): {detail[:500]}")


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
            raise ASCHttpError(method, path, e.code, detail) from e


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


def wait_for_valid_build(
    client: ASCClient,
    app_id: str,
    build_number: str,
    version: str | None,
    timeout_seconds: int = 1200,
) -> str:
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
                return build_id
        time.sleep(20)
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


def upsert_beta_build_localization(
    client: ASCClient,
    build_id: str,
    locale: str,
    whats_new: str,
) -> None:
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


def sync_whats_new(
    client: ASCClient,
    bundle_id: str,
    build_number: str,
    version: str | None,
    changelog: str,
    locale: str = "zh-Hans",
    timeout_seconds: int = 1200,
) -> None:
    if locale.lower().startswith("en"):
        whats_new = build_en_whats_new(version=version, build=build_number)
    elif locale.lower().startswith("zh"):
        whats_new = build_zh_whats_new(version=version, build=build_number)
    else:
        whats_new = extract_changelog(changelog, version=version, build=build_number)
    app = find_app(client, bundle_id)
    if not app:
        raise RuntimeError(f"No app found in App Store Connect for {bundle_id}")
    build_id = wait_for_valid_build(client, app["id"], build_number, version, timeout_seconds=timeout_seconds)
    upsert_beta_build_localization(client, build_id, locale=locale, whats_new=whats_new)
    print(f"::notice title=TestFlight 测试信息已同步::build {build_number} ({locale})")


def sync_beta_app_localizations(
    client: ASCClient,
    app_id: str,
    feedback_email: str = "",
) -> None:
    existing_locs = client.request("GET", f"/apps/{app_id}/betaAppLocalizations").get("data", [])
    for locale, description in PUBLIC_BETA_APP_DESCRIPTIONS.items():
        attrs: dict[str, str] = {
            "description": description,
            "marketingUrl": SUPPORT_URL,
            "privacyPolicyUrl": PRIVACY_URL,
        }
        if feedback_email.strip():
            attrs["feedbackEmail"] = feedback_email.strip()

        existing = next((x for x in existing_locs if x.get("attributes", {}).get("locale") == locale), None)
        try:
            if existing:
                loc_id = existing["id"]
                client.request(
                    "PATCH",
                    f"/betaAppLocalizations/{loc_id}",
                    {"data": {"type": "betaAppLocalizations", "id": loc_id, "attributes": attrs}},
                )
            else:
                attrs["locale"] = locale
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
            print(f"::warning title=BetaAppLocalization ({locale}) Skipped::{e.code} {e.detail[:220]}")


def sync_beta_review_details(
    client: ASCClient,
    app_id: str,
    version: str = "2.2.0",
    contact_first: str = "",
    contact_last: str = "",
    contact_email: str = "",
    contact_phone: str = "",
) -> dict:
    try:
        resp = client.request("GET", f"/apps/{app_id}/betaAppReviewDetail")
        detail = resp.get("data")
    except ASCHttpError as e:
        if e.code == 404:
            detail = None
        else:
            raise

    attrs: dict[str, object] = {
        "demoAccountRequired": False,
        "notes": PUBLIC_BETA_REVIEW_NOTES_TEMPLATE.format(version=version or "2.2.0"),
    }
    if contact_first.strip():
        attrs["contactFirstName"] = contact_first.strip()
    if contact_last.strip():
        attrs["contactLastName"] = contact_last.strip()
    if contact_email.strip():
        attrs["contactEmail"] = contact_email.strip()
    if contact_phone.strip():
        attrs["contactPhone"] = contact_phone.strip()

    if detail and detail.get("id"):
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
            print(f"::warning title=TestFlight Review Details Skipped::{e.code} {e.detail[:220]}")
            return detail
    else:
        print("::warning title=TestFlight Review Contact Missing::betaAppReviewDetails ID not yet present; review notes skipped.")
        return {}


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
            print(
                f"::warning title=TestFlight Public Link Pending::将在公测审核通过后可开启公开链接 ({e.code})"
            )
    return group_id


def submit_beta_review(client: ASCClient, build_id: str) -> None:
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
        print(
            "::warning title=TestFlight 公测提审需要补齐联系信息::"
            f"App Store Connect 返回 {e.code}，请确认已在 TestFlight -> 测试信息 填好反馈邮箱与审核联系人电话后重试 ({e.detail[:240]})"
        )


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
) -> None:
    app = find_app(client, bundle_id)
    if not app:
        raise RuntimeError(f"No app found in App Store Connect for {bundle_id}")
    app_id = app["id"]
    build_id = wait_for_valid_build(client, app_id, build_number, version, timeout_seconds=timeout_seconds)

    zh_whats_new = build_zh_whats_new(version=version, build=build_number)
    upsert_beta_build_localization(client, build_id, locale="zh-Hans", whats_new=zh_whats_new)

    en_whats_new = build_en_whats_new(version=version, build=build_number)
    upsert_beta_build_localization(client, build_id, locale="en-US", whats_new=en_whats_new)

    sync_beta_app_localizations(client, app_id, feedback_email=feedback_email)
    sync_beta_review_details(
        client,
        app_id,
        version=version or "2.2.0",
        contact_first=contact_first,
        contact_last=contact_last,
        contact_email=contact_email,
        contact_phone=contact_phone,
    )
    ensure_external_beta_group(
        client,
        app_id,
        group_name=group_name,
        public_link=public_link,
        build_id=build_id,
    )
    if submit_review:
        submit_beta_review(client, build_id)


def audit_beta_readiness(client: ASCClient, bundle_id: str, build_number: str = "") -> int:
    app = find_app(client, bundle_id)
    if not app:
        print(f"[AUDIT] App NOT found for {bundle_id}")
        return 2
    app_id = app["id"]
    print(f"[AUDIT] App: {app.get('attributes', {}).get('name')} ({bundle_id}, id={app_id})")

    locs = client.request("GET", f"/apps/{app_id}/betaAppLocalizations").get("data", [])
    print(f"[AUDIT] BetaAppLocalizations: {[l.get('attributes', {}).get('locale') for l in locs]}")
    for loc in locs:
        a = loc.get("attributes", {})
        print(
            f"  - {a.get('locale')}: feedbackEmail={'YES' if a.get('feedbackEmail') else 'MISSING'}, "
            f"privacyUrl={'YES' if a.get('privacyPolicyUrl') else 'MISSING'}"
        )

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
    except ASCHttpError as e:
        print(f"[AUDIT] ReviewDetails fetch error ({e.code})")

    groups = client.request("GET", f"/apps/{app_id}/betaGroups?limit=200").get("data", [])
    ext_groups = [g for g in groups if not g.get("attributes", {}).get("isInternalGroup", False)]
    print(
        f"[AUDIT] External BetaGroups ({len(ext_groups)}): "
        + ", ".join(
            f"{g.get('attributes', {}).get('name')}(enabled={g.get('attributes', {}).get('publicLinkEnabled')}, publicLink={g.get('attributes', {}).get('publicLink') or 'off'})"
            for g in ext_groups
        )
    )

    try:
        params = {"filter[app]": app_id, "limit": "5", "sort": "-uploadedDate"}
        if build_number.strip():
            params["filter[version]"] = build_number.strip()
        builds = client.request("GET", f"/builds?{urllib.parse.urlencode(params)}").get("data", [])
        if builds:
            b = builds[0]
            b_ver = b.get("attributes", {}).get("version", "")
            b_state = b.get("attributes", {}).get("processingState", "")
            review_state = "NOT_SUBMITTED"
            try:
                sub = client.request("GET", f"/builds/{b['id']}/betaAppReviewSubmission").get("data")
                if sub:
                    review_state = sub.get("attributes", {}).get("betaReviewState", "UNKNOWN")
            except ASCHttpError as se:
                if se.code != 404:
                    review_state = f"ERR_{se.code}"
            print(f"[AUDIT] LatestBuild: build={b_ver}, processingState={b_state}, betaReviewState={review_state}")
    except ASCHttpError as e:
        print(f"[AUDIT] LatestBuild fetch error ({e.code})")
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

    p3 = sub.add_parser("sync-whats-new")
    p3.add_argument("--bundle-id", default="app.chimmo")
    p3.add_argument("--build", required=True)
    p3.add_argument("--version", default="")
    p3.add_argument("--changelog", default="CHANGELOG.md")
    p3.add_argument("--locale", default="zh-Hans")
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
    p4.add_argument("--feedback-email", default="")
    p4.add_argument("--contact-first", default="")
    p4.add_argument("--contact-last", default="")
    p4.add_argument("--contact-email", default="")
    p4.add_argument("--contact-phone", default="")
    p4.add_argument("--key-path", default=None)
    p4.add_argument("--timeout", type=int, default=1200)

    p5 = sub.add_parser("audit-beta-readiness")
    p5.add_argument("bundle_id")
    p5.add_argument("--build", default="")
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
            )
            return 0
        if args.cmd == "audit-beta-readiness":
            return audit_beta_readiness(client, args.bundle_id, build_number=args.build)
    finally:
        if tmp and os.path.exists(tmp):
            os.remove(tmp)
    return 0


if __name__ == "__main__":
    sys.exit(main())
