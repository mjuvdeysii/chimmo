#!/usr/bin/env python3
"""Zero-dependency static compliance, security, and asset gate for Chimmo CI.

Usage:
  python3 Tools/ci_guard.py
  python3 Tools/ci_guard.py --build-log build.log --require-tests
"""

from __future__ import annotations

import sys

sys.dont_write_bytecode = True

import argparse
import ast
import json
import os
import plistlib
import re
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SKIP_DIRS = {".git", "Chimmo.xcodeproj", ".build", "DerivedData", "build", "shots", "__pycache__"}
BINARY_EXTS = {".png", ".jpg", ".jpeg", ".wav", ".caf", ".pdf", ".zip", ".icns"}

EMOJI_RE = re.compile(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]")
NETWORK_RE = re.compile(r"\b(URLSession|NWConnection|NWPathMonitor|CFNetwork|WKWebView|SFSafariViewController)\b")
DISALLOWED_MEDICAL_RE = re.compile(
    r"(\u62a4\u8033|\u62a4\u773c|\u52a9\u7720|\u6cbb\u7597\u5931\u7720|\u7f13\u89e3\u7126\u8651|\u6cbb\u5931\u7720|\u8111\u7535\u6ce2\u5939\u5e26)"
)
UNDECLARED_FILE_TS_RE = re.compile(
    r"\b(contentModificationDate|creationDate|fileModificationDate|attributesOfItem)\b"
)
UNDECLARED_DISK_SPACE_RE = re.compile(r"\b(volumeAvailableCapacity|systemFreeSize|volumeTotalCapacity)\b")
UNDECLARED_KEYBOARDS_RE = re.compile(r"\bactiveInputModes\b")
LOCALIZED_KEY_RE = re.compile(r'String\(\s*localized:\s*"([^"]+)"')
UNSAFE_JS_SINK_RE = re.compile(r"\b(eval\s*\(|document\.write\s*\(|new\s+Function\s*\()")
LOCAL_USER_LINK_RE = re.compile(r"file:///Users/")


def _iter_workspace_files() -> list[Path]:
    files: list[Path] = []
    for dp, dns, fns in os.walk(ROOT):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for fn in sorted(fns):
            files.append(Path(dp) / fn)
    return files


def _iter_swift_files() -> list[Path]:
    swift_root = ROOT / "Chimmo"
    return sorted(swift_root.rglob("*.swift"))


def check_zero_emoji() -> list[str]:
    errs: list[str] = []
    for fp in _iter_workspace_files():
        if fp.suffix.lower() in BINARY_EXTS:
            continue
        rel = fp.relative_to(ROOT).as_posix()
        try:
            text = fp.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for idx, line in enumerate(text.splitlines(), 1):
            if EMOJI_RE.search(line):
                errs.append(f"Emoji detected at {rel}:{idx}")
    return errs


def check_zero_networking() -> list[str]:
    errs: list[str] = []
    for fp in _iter_swift_files():
        rel = fp.relative_to(ROOT).as_posix()
        for idx, line in enumerate(fp.read_text(encoding="utf-8").splitlines(), 1):
            if NETWORK_RE.search(line):
                errs.append(f"Disallowed networking symbol at {rel}:{idx}: {line.strip()}")
    return errs


def check_medical_wording() -> list[str]:
    errs: list[str] = []
    targets: list[Path] = []
    for rel_target in ("Chimmo", "docs", "Tools/asc.py", "CHANGELOG.md"):
        p = ROOT / rel_target
        if p.is_file():
            targets.append(p)
        elif p.is_dir():
            for fp in sorted(p.rglob("*")):
                if fp.is_file() and fp.suffix.lower() in {".swift", ".html", ".md", ".xcstrings", ".plist", ".py"}:
                    targets.append(fp)
    for fp in targets:
        rel = fp.relative_to(ROOT).as_posix()
        for idx, line in enumerate(fp.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
            m = DISALLOWED_MEDICAL_RE.search(line)
            if m:
                errs.append(f"Disallowed health/sleep claim '{m.group(1)}' at {rel}:{idx}")
    return errs


def check_privacy_manifest() -> list[str]:
    errs: list[str] = []
    p = ROOT / "Chimmo/Resources/PrivacyInfo.xcprivacy"
    if not p.exists():
        return [f"Missing PrivacyInfo.xcprivacy at {p}"]
    try:
        with p.open("rb") as f:
            data = plistlib.load(f)
    except Exception as exc:
        return [f"Invalid PrivacyInfo.xcprivacy plist: {exc}"]

    if data.get("NSPrivacyTracking") is not False:
        errs.append("PrivacyInfo.xcprivacy NSPrivacyTracking must be false")
    if data.get("NSPrivacyTrackingDomains") != []:
        errs.append("PrivacyInfo.xcprivacy NSPrivacyTrackingDomains must be empty []")
    if data.get("NSPrivacyCollectedDataTypes") != []:
        errs.append("PrivacyInfo.xcprivacy NSPrivacyCollectedDataTypes must be empty []")

    declared: dict[str, set[str]] = {}
    for entry in data.get("NSPrivacyAccessedAPITypes", []):
        api_type = entry.get("NSPrivacyAccessedAPIType", "")
        reasons = set(entry.get("NSPrivacyAccessedAPITypeReasons", []))
        declared[api_type] = reasons

    if "CA92.1" not in declared.get("NSPrivacyAccessedAPICategoryUserDefaults", set()):
        errs.append("PrivacyInfo.xcprivacy missing NSPrivacyAccessedAPICategoryUserDefaults reason CA92.1")
    if "35F9.1" not in declared.get("NSPrivacyAccessedAPICategorySystemBootTime", set()):
        errs.append("PrivacyInfo.xcprivacy missing NSPrivacyAccessedAPICategorySystemBootTime reason 35F9.1")

    for fp in _iter_swift_files():
        rel = fp.relative_to(ROOT).as_posix()
        for idx, line in enumerate(fp.read_text(encoding="utf-8").splitlines(), 1):
            for pat, name in (
                (UNDECLARED_FILE_TS_RE, "FileTimestamp"),
                (UNDECLARED_DISK_SPACE_RE, "DiskSpace"),
                (UNDECLARED_KEYBOARDS_RE, "ActiveKeyboards"),
            ):
                if pat.search(line):
                    errs.append(f"Undeclared Required Reason API ({name}) at {rel}:{idx}")
    return errs


def check_info_plist_parity() -> list[str]:
    errs: list[str] = []
    plist_path = ROOT / "Chimmo/Resources/Info.plist"
    xcstrings_path = ROOT / "Chimmo/Resources/InfoPlist.xcstrings"
    try:
        with plist_path.open("rb") as f:
            info = plistlib.load(f)
    except Exception as exc:
        return [f"Invalid Info.plist: {exc}"]

    if info.get("ITSAppUsesNonExemptEncryption") is not False:
        errs.append("Info.plist ITSAppUsesNonExemptEncryption must be false")
    if "audio" not in (info.get("UIBackgroundModes") or []):
        errs.append("Info.plist UIBackgroundModes must contain 'audio'")
    for key in ("NSMicrophoneUsageDescription", "NSPhotoLibraryAddUsageDescription"):
        if not str(info.get(key, "")).strip():
            errs.append(f"Info.plist missing or empty {key}")
    locs = set(info.get("CFBundleLocalizations") or [])
    if not {"zh-Hans", "en"}.issubset(locs):
        errs.append("Info.plist CFBundleLocalizations must include zh-Hans and en")

    try:
        xcs = json.loads(xcstrings_path.read_text(encoding="utf-8")).get("strings", {})
    except Exception as exc:
        return [f"Invalid InfoPlist.xcstrings: {exc}"]

    for key in (
        "CFBundleDisplayName",
        "CFBundleName",
        "NSMicrophoneUsageDescription",
        "NSPhotoLibraryAddUsageDescription",
    ):
        entry_locs = xcs.get(key, {}).get("localizations", {})
        for lang in ("zh-Hans", "en"):
            val = entry_locs.get(lang, {}).get("stringUnit", {}).get("value", "")
            if not str(val).strip():
                errs.append(f"InfoPlist.xcstrings missing '{lang}' value for '{key}'")
    return errs


def check_localizable_xcstrings() -> list[str]:
    errs: list[str] = []
    xc_path = ROOT / "Chimmo/Resources/Localizable.xcstrings"
    try:
        strings = json.loads(xc_path.read_text(encoding="utf-8")).get("strings", {})
    except Exception as exc:
        return [f"Invalid Localizable.xcstrings JSON: {exc}"]

    if not strings:
        return ["Localizable.xcstrings contains 0 keys"]

    for key, val in strings.items():
        locs = val.get("localizations", {})
        for lang in ("zh-Hans", "en"):
            text = locs.get(lang, {}).get("stringUnit", {}).get("value", "")
            if not str(text).strip():
                errs.append(f"Localizable.xcstrings key '{key}' missing '{lang}' translation")

    for fp in _iter_swift_files():
        rel = fp.relative_to(ROOT).as_posix()
        for idx, line in enumerate(fp.read_text(encoding="utf-8").splitlines(), 1):
            s = line.strip()
            if s.startswith("//"):
                continue
            for m in LOCALIZED_KEY_RE.finditer(line):
                key = m.group(1)
                if "\\(" in key:
                    continue
                if key not in strings:
                    errs.append(f"Missing localization key '{key}' referenced at {rel}:{idx}")
    return errs


def check_app_icons() -> list[str]:
    errs: list[str] = []
    icon_dir = ROOT / "Chimmo/Resources/Assets.xcassets/AppIcon.appiconset"
    for name in ("AppIcon-Light.png", "AppIcon-Dark.png", "AppIcon-Tinted.png"):
        p = icon_dir / name
        if not p.exists():
            errs.append(f"Missing App Icon PNG: {p.relative_to(ROOT)}")
            continue
        raw = p.read_bytes()
        if len(raw) < 33 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
            errs.append(f"Invalid PNG header/IHDR in {name}")
            continue
        width, height, bit_depth, color_type = struct.unpack(">IIBB", raw[16:26])
        if width != 1024 or height != 1024:
            errs.append(f"{name} must be 1024x1024, got {width}x{height}")
        if color_type != 2 or bit_depth != 8:
            errs.append(f"{name} must be 8-bit opaque RGB (color_type=2), got color_type={color_type}, bit_depth={bit_depth}")
    return errs


def check_web_and_docs() -> list[str]:
    errs: list[str] = []
    node_path = None
    for candidate in ("node", "/usr/local/bin/node", "/opt/homebrew/bin/node"):
        res = subprocess.run(["which", candidate], capture_output=True, text=True)
        if res.returncode == 0:
            node_path = res.stdout.strip()
            break

    docs_dir = ROOT / "docs"
    for html_path in sorted(docs_dir.glob("*.html")):
        rel = html_path.relative_to(ROOT).as_posix()
        html = html_path.read_text(encoding="utf-8")
        for idx, line in enumerate(html.splitlines(), 1):
            if UNSAFE_JS_SINK_RE.search(line):
                errs.append(f"Unsafe JS sink pattern at {rel}:{idx}")
            if LOCAL_USER_LINK_RE.search(line):
                errs.append(f"Local machine link at {rel}:{idx}")
        if node_path:
            for s_idx, m in enumerate(re.finditer(r"<script[^>]*>([\s\S]*?)</script>", html)):
                script_body = m.group(1).strip()
                if not script_body:
                    continue
                with tempfile.NamedTemporaryFile("w", suffix=".js", encoding="utf-8", delete=False) as tf:
                    tf.write(script_body)
                    tmp_js = tf.name
                try:
                    chk = subprocess.run([node_path, "--check", tmp_js], capture_output=True, text=True)
                    if chk.returncode != 0:
                        errs.append(f"JS syntax error in {rel} script#{s_idx}: {chk.stderr.strip()}")
                finally:
                    os.unlink(tmp_js)

    for md_path in [*sorted(docs_dir.glob("*.md")), ROOT / "README.md"]:
        if not md_path.exists():
            continue
        rel = md_path.relative_to(ROOT).as_posix()
        for idx, line in enumerate(md_path.read_text(encoding="utf-8").splitlines(), 1):
            if LOCAL_USER_LINK_RE.search(line):
                errs.append(f"Local machine file:// link at {rel}:{idx}")
    return errs


def check_git_hygiene() -> list[str]:
    if not (ROOT / ".git").exists():
        return []
    res = subprocess.run(["git", "-C", str(ROOT), "ls-files"], capture_output=True, text=True)
    if res.returncode != 0:
        return [f"git ls-files failed: {res.stderr.strip()}"]
    errs: list[str] = []
    for tracked in res.stdout.splitlines():
        if "Chimmo.xcodeproj" in tracked or tracked.endswith(".p8") or tracked.startswith("shots/"):
            errs.append(f"Forbidden artifact tracked in git index: {tracked}")
    return errs


def check_python_tools_and_tests() -> list[str]:
    errs: list[str] = []
    for py_path in (ROOT / "Tools/asc.py", ROOT / "Tools/ci_guard.py"):
        try:
            ast.parse(py_path.read_text(encoding="utf-8"), filename=str(py_path))
        except SyntaxError as exc:
            errs.append(f"Python syntax error in {py_path.relative_to(ROOT)}: {exc}")

    tests_dir = ROOT / "Tools/tests"
    if not tests_dir.is_dir():
        return errs + ["Missing Tools/tests unit test directory"]

    loader = unittest.TestLoader()
    suite = loader.discover(start_dir=str(tests_dir), pattern="test_*.py", top_level_dir=str(tests_dir))
    if suite.countTestCases() == 0:
        return errs + ["No unit tests discovered in Tools/tests"]

    runner = unittest.TextTestRunner(verbosity=1)
    result = runner.run(suite)
    if not result.wasSuccessful():
        errs.append(
            f"Python CI tooling tests failed (failures={len(result.failures)}, errors={len(result.errors)})"
        )
    return errs


def check_build_log(build_log: Path, require_tests: bool) -> list[str]:
    errs: list[str] = []
    if not build_log.exists():
        return [f"Missing xcodebuild log file: {build_log}"]
    content = build_log.read_text(encoding="utf-8", errors="ignore")
    for idx, line in enumerate(content.splitlines(), 1):
        if ": warning:" in line and "/Chimmo/" in line:
            errs.append(f"Swift compiler warning in Chimmo source (build.log:{idx}): {line.strip()}")

    if require_tests:
        executed = re.findall(r"Test Case .* (passed|failed)", content)
        failed = [m for m in executed if m == "failed"]
        if not executed:
            errs.append("Zero XCTest cases were executed in build log")
        elif failed:
            errs.append(f"{len(failed)} XCTest cases failed in build log")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser(description="Chimmo CI static compliance, asset, and log verifier")
    ap.add_argument("--build-log", default="", help="Optional path to xcodebuild log to verify zero Swift warnings")
    ap.add_argument("--require-tests", action="store_true", help="Fail unless >=1 XCTest case passed in --build-log")
    args = ap.parse_args()

    checks: list[tuple[str, list[str]]] = [
        ("zero_emoji", check_zero_emoji()),
        ("zero_networking", check_zero_networking()),
        ("non_medical_wording", check_medical_wording()),
        ("privacy_manifest", check_privacy_manifest()),
        ("info_plist_parity", check_info_plist_parity()),
        ("localizable_xcstrings", check_localizable_xcstrings()),
        ("app_icons_spec", check_app_icons()),
        ("web_and_docs", check_web_and_docs()),
        ("git_hygiene", check_git_hygiene()),
        ("python_tools_and_tests", check_python_tools_and_tests()),
    ]
    if args.build_log:
        checks.append(("xcodebuild_log", check_build_log(Path(args.build_log), require_tests=args.require_tests)))

    all_errors: list[str] = []
    for name, errs in checks:
        status = "PASS" if not errs else f"FAIL ({len(errs)})"
        print(f"[CI_GUARD] {name}: {status}")
        for err in errs:
            print(f"  - {err}")
        all_errors.extend(errs)

    if all_errors:
        print(f"[CI_GUARD] FAILED with {len(all_errors)} violation(s)", file=sys.stderr)
        return 1
    print(f"[CI_GUARD] ALL {len(checks)} CHECKS PASSED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
