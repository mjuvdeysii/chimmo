#!/usr/bin/env python3
"""Offline unit tests for Tools/asc.py (zero network calls)."""

from __future__ import annotations

import sys

sys.dont_write_bytecode = True

import contextlib
import io
import json
import os
import tempfile
import unittest
import urllib.error
from email.message import Message
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "Tools"))

import asc  # noqa: E402


class _FakeHTTPResponse:
    def __init__(self, payload: dict):
        self._raw = json.dumps(payload).encode("utf-8")

    def read(self) -> bytes:
        return self._raw

    def __enter__(self) -> "_FakeHTTPResponse":
        return self

    def __exit__(self, *args: object) -> None:
        return None


class _StubASCClient(asc.ASCClient):
    def __init__(self, routes: dict[tuple[str, str], object]):
        super().__init__(
            key_id="K1",
            issuer_id="I1",
            key_path="/dev/null",
            sleep_fn=lambda _: None,
            token_factory=lambda *_: "jwt",
        )
        self.routes = routes
        self.calls: list[tuple[str, str, dict | None]] = []

    def request(self, method: str, path: str, body: dict | None = None) -> dict:
        self.calls.append((method, path, body))
        handler = self.routes.get((method, path))
        if handler is None:
            for (m, prefix), h in self.routes.items():
                if m == method and path.startswith(prefix):
                    handler = h
                    break
        if callable(handler):
            res = handler(method, path, body)
        else:
            res = handler
        if isinstance(res, Exception):
            raise res
        return res if isinstance(res, dict) else {}


class ASCHelperTests(unittest.TestCase):
    def test_der_ecdsa_to_raw_valid_and_invalid(self) -> None:
        r = b"\x00" + b"\x11" * 32  # 33 bytes with DER sign-bit padding
        s = b"\x22" * 31            # 31 bytes (left-padded with 0x00)
        der = bytes([0x30, 2 + len(r) + 2 + len(s), 0x02, len(r)]) + r + bytes([0x02, len(s)]) + s
        raw = asc.der_ecdsa_to_raw(der, 32)
        self.assertEqual(len(raw), 64)
        self.assertEqual(raw[:32], b"\x11" * 32)
        self.assertEqual(raw[32:], b"\x00" + b"\x22" * 31)

        with self.assertRaises(ValueError):
            asc.der_ecdsa_to_raw(b"\x31\x06\x02\x01\x01\x02\x01\x01")
        with self.assertRaises(ValueError):
            asc.der_ecdsa_to_raw(b"\x30\x04\x03\x01\x01\x02")

    def test_request_retries_429_503_and_refreshes_401(self) -> None:
        sleeps: list[float] = []
        token_calls = 0

        def next_token(_k: str, _i: str, _p: str) -> str:
            nonlocal token_calls
            token_calls += 1
            return f"jwt-{token_calls}"

        seen_auth: list[str] = []
        seq = [
            urllib.error.HTTPError("https://api.example", 401, "Unauthorized", Message(), io.BytesIO(b"expired")),
            urllib.error.HTTPError(
                "https://api.example",
                429,
                "Too Many Requests",
                self._headers({"Retry-After": "2"}),
                io.BytesIO(b"rate limit"),
            ),
            urllib.error.HTTPError("https://api.example", 503, "Unavailable", Message(), io.BytesIO(b"busy")),
            _FakeHTTPResponse({"data": [{"id": "app-1"}]}),
        ]

        def opener(req, timeout=30):
            seen_auth.append(req.get_header("Authorization"))
            nxt = seq.pop(0)
            if isinstance(nxt, Exception):
                raise nxt
            return nxt

        client = asc.ASCClient(
            key_id="K1",
            issuer_id="I1",
            key_path="/dev/null",
            max_retries=4,
            sleep_fn=sleeps.append,
            opener=opener,
            token_factory=next_token,
        )
        res = client.request("GET", "/apps")
        self.assertEqual(res["data"][0]["id"], "app-1")
        self.assertEqual(token_calls, 2)
        self.assertEqual(seen_auth[0], "Bearer jwt-1")
        self.assertEqual(seen_auth[1], "Bearer jwt-2")
        self.assertEqual(sleeps, [2.0, 6.0])

        # Non-retryable 422 raises immediately without backoff
        sleeps.clear()
        client422 = asc.ASCClient(
            key_id="K1",
            issuer_id="I1",
            key_path="/dev/null",
            max_retries=3,
            sleep_fn=sleeps.append,
            opener=lambda _r, timeout=30: (_ for _ in ()).throw(
                urllib.error.HTTPError("https://api.example", 422, "Unprocessable", Message(), io.BytesIO(b"missing"))
            ),
            token_factory=lambda *_: "jwt",
        )
        with self.assertRaises(asc.ASCHttpError) as ctx:
            client422.request("POST", "/betaAppReviewSubmissions", {})
        self.assertEqual(ctx.exception.code, 422)
        self.assertEqual(sleeps, [])

    def test_whats_new_builders_and_changelog_extraction(self) -> None:
        zh = asc.build_zh_whats_new(version="2.2.0", build="180")
        en = asc.build_en_whats_new(version="2.2.0", build="180")
        self.assertIn("Build 180", zh)
        self.assertIn("Build 180", en)
        self.assertLessEqual(len(zh), asc.MAX_WHATS_NEW_CHARS)
        self.assertLessEqual(len(en), asc.MAX_WHATS_NEW_CHARS)
        extracted = asc.extract_changelog(str(ROOT / "CHANGELOG.md"), version="2.2.0", build="180")
        self.assertIn("dual parallel DSP", extracted)
        self.assertNotIn("[", extracted)

    def test_next_build_number_monotonicity(self) -> None:
        client = _StubASCClient(
            {
                ("GET", "/apps?"): {"data": [{"id": "app1", "attributes": {"bundleId": "app.chimmo"}}]},
                ("GET", "/builds?"): {
                    "data": [
                        {"id": "b1", "attributes": {"version": "176"}},
                        {"id": "b2", "attributes": {"version": "bad-str"}},
                        {"id": "b3", "attributes": {"version": "105"}},
                    ]
                },
            }
        )
        self.assertEqual(asc.next_build_number(client, "app.chimmo", min_build=101), 177)
        self.assertEqual(asc.next_build_number(client, "app.chimmo", min_build=250), 250)

    def test_sync_whats_new_single_poll_multi_locale(self) -> None:
        client = _StubASCClient(
            {
                ("GET", "/apps?"): {"data": [{"id": "app1", "attributes": {"bundleId": "app.chimmo"}}]},
                ("GET", "/builds?"): {"data": [{"id": "build-180", "attributes": {"processingState": "VALID"}}]},
                ("GET", "/builds/build-180/betaBuildLocalizations"): {
                    "data": [{"id": "loc-zh", "attributes": {"locale": "zh-Hans"}}]
                },
                ("PATCH", "/betaBuildLocalizations/loc-zh"): {"data": {}},
                ("POST", "/betaBuildLocalizations"): {"data": {}},
            }
        )
        asc.sync_whats_new(
            client,
            bundle_id="app.chimmo",
            build_number="180",
            version="2.2.0",
            changelog=str(ROOT / "CHANGELOG.md"),
            locales=["zh-Hans", "en-US"],
        )
        build_polls = [c for c in client.calls if c[0] == "GET" and c[1].startswith("/builds?")]
        self.assertEqual(len(build_polls), 1)
        patch_calls = [c for c in client.calls if c[0] == "PATCH" and c[1] == "/betaBuildLocalizations/loc-zh"]
        post_calls = [c for c in client.calls if c[0] == "POST" and c[1] == "/betaBuildLocalizations"]
        self.assertEqual(len(patch_calls), 1)
        self.assertEqual(len(post_calls), 1)
        self.assertEqual(post_calls[0][2]["data"]["attributes"]["locale"], "en-US")

    def test_sync_beta_review_details_merges_and_strict_preflight(self) -> None:
        # Missing fields + strict=True aborts BEFORE sending broken PATCH (zero 409)
        incomplete_client = _StubASCClient(
            {
                ("GET", "/apps/app1/betaAppReviewDetail"): {
                    "data": {"id": "rev1", "attributes": {"contactFirstName": "Lin"}}
                }
            }
        )
        with self.assertRaises(RuntimeError) as ctx:
            asc.sync_beta_review_details(incomplete_client, "app1", version="2.2.0", strict=True)
        self.assertIn("BETA_CONTACT_PHONE", str(ctx.exception))
        self.assertFalse(any(m == "PATCH" for m, _, _ in incomplete_client.calls))

        # Existing ASC contacts + partial CLI override cleanly merge and PATCH
        complete_client = _StubASCClient(
            {
                ("GET", "/apps/app1/betaAppReviewDetail"): {
                    "data": {
                        "id": "rev1",
                        "attributes": {
                            "contactFirstName": "Lin",
                            "contactLastName": "Chen",
                            "contactEmail": "old@example.com",
                            "contactPhone": "+8613800000000",
                        },
                    }
                },
                ("PATCH", "/betaAppReviewDetails/rev1"): {"data": {"id": "rev1"}},
            }
        )
        asc.sync_beta_review_details(
            complete_client,
            "app1",
            version="2.2.0",
            contact_email="new@example.com",
            strict=True,
        )
        patches = [c for c in complete_client.calls if c[0] == "PATCH"]
        self.assertEqual(len(patches), 1)
        attrs = patches[0][2]["data"]["attributes"]
        self.assertEqual(attrs["contactFirstName"], "Lin")
        self.assertEqual(attrs["contactEmail"], "new@example.com")
        self.assertIn("Pure Ambient Wash", attrs["notes"])

    def test_audit_beta_readiness_detects_blocked_and_ready(self) -> None:
        blocked = _StubASCClient(
            {
                ("GET", "/apps?"): {"data": [{"id": "app1", "attributes": {"bundleId": "app.chimmo", "name": "咩哞"}}]},
                ("GET", "/apps/app1/betaAppLocalizations"): {
                    "data": [{"id": "l1", "attributes": {"locale": "zh-Hans", "privacyPolicyUrl": asc.PRIVACY_URL, "description": "ok"}}]
                },
                ("GET", "/apps/app1/betaAppReviewDetail"): {"data": {"id": "r1", "attributes": {}}},
                ("GET", "/apps/app1/betaGroups?"): {"data": []},
                ("GET", "/builds?"): {
                    "data": [{"id": "b1", "attributes": {"version": "176", "processingState": "VALID", "usesNonExemptEncryption": False}}]
                },
                ("GET", "/builds/b1/betaBuildLocalizations"): {"data": []},
                ("GET", "/builds/b1/betaAppReviewSubmission"): asc.ASCHttpError("GET", "/sub", 404, "none"),
            }
        )
        self.assertEqual(asc.audit_beta_readiness(blocked, "app.chimmo", fail_if_unready=True), 3)

        ready = _StubASCClient(
            {
                ("GET", "/apps?"): {"data": [{"id": "app1", "attributes": {"bundleId": "app.chimmo", "name": "咩哞"}}]},
                ("GET", "/apps/app1/betaAppLocalizations"): {
                    "data": [
                        {"id": "l1", "attributes": {"locale": "zh-Hans", "feedbackEmail": "f@example.com", "privacyPolicyUrl": asc.PRIVACY_URL, "description": "zh"}},
                        {"id": "l2", "attributes": {"locale": "en-US", "feedbackEmail": "f@example.com", "privacyPolicyUrl": asc.PRIVACY_URL, "description": "en"}},
                    ]
                },
                ("GET", "/apps/app1/betaAppReviewDetail"): {
                    "data": {
                        "id": "r1",
                        "attributes": {
                            "contactFirstName": "A",
                            "contactLastName": "B",
                            "contactEmail": "c@example.com",
                            "contactPhone": "+8613800000000",
                            "notes": "notes",
                        },
                    }
                },
                ("GET", "/apps/app1/betaGroups?"): {
                    "data": [{"id": "g1", "attributes": {"name": "公测", "isInternalGroup": False, "publicLinkEnabled": True}}]
                },
                ("GET", "/builds?"): {
                    "data": [{"id": "b1", "attributes": {"version": "177", "processingState": "VALID", "usesNonExemptEncryption": False}}]
                },
                ("GET", "/builds/b1/betaBuildLocalizations"): {
                    "data": [
                        {"id": "bl1", "attributes": {"locale": "zh-Hans", "whatsNew": "zh"}},
                        {"id": "bl2", "attributes": {"locale": "en-US", "whatsNew": "en"}},
                    ]
                },
                ("GET", "/builds/b1/betaAppReviewSubmission"): {"data": {"attributes": {"betaReviewState": "APPROVED"}}},
            }
        )
        self.assertEqual(asc.audit_beta_readiness(ready, "app.chimmo", build_number="177", fail_if_unready=True), 0)

    def test_resolve_key_file_permissions(self) -> None:
        old = os.environ.get("ASC_KEY_P8")
        os.environ["ASC_KEY_P8"] = "PRIVATE_KEY_MATERIAL"
        try:
            kf, tmp = asc.resolve_key_file(None)
            assert tmp is not None
            mode = os.stat(tmp).st_mode & 0o777
            self.assertEqual(mode, 0o600)
            os.remove(tmp)
        finally:
            if old is None:
                os.environ.pop("ASC_KEY_P8", None)
            else:
                os.environ["ASC_KEY_P8"] = old

    def test_fetch_team_fallback_contacts_discovers_across_sources_and_skips_404(self) -> None:
        client = _StubASCClient(
            {
                ("GET", "/apps?limit=50"): {
                    "data": [
                        {"id": "app-target", "attributes": {"bundleId": "app.chimmo"}},
                        {"id": "app-broken", "attributes": {"bundleId": "app.broken"}},
                        {"id": "app-sibling", "attributes": {"bundleId": "app.sample"}},
                    ]
                },
                ("GET", "/apps/app-broken/betaAppReviewDetail"): asc.ASCHttpError("GET", "/betaAppReviewDetail", 404, "missing"),
                ("GET", "/apps/app-broken/appStoreVersions?limit=5&include=appStoreReviewDetail"): asc.ASCHttpError("GET", "/appStoreVersions", 404, "missing"),
                ("GET", "/apps/app-broken/betaAppLocalizations"): asc.ASCHttpError("GET", "/betaAppLocalizations", 404, "missing"),
                ("GET", "/apps/app-sibling/betaAppReviewDetail"): {
                    "data": {
                        "id": "rev-s",
                        "attributes": {
                            "contactFirstName": "SampleFirst",
                            "contactLastName": "SampleLast",
                        },
                    }
                },
                ("GET", "/apps/app-sibling/appStoreVersions?limit=5&include=appStoreReviewDetail"): {
                    "data": [{"id": "ver-1"}],
                    "included": [
                        {
                            "type": "appStoreReviewDetails",
                            "id": "asrev-1",
                            "attributes": {
                                "contactEmail": "team-review@example.com",
                                "contactPhone": "+8613900001234",
                            },
                        }
                    ],
                },
                ("GET", "/apps/app-sibling/betaAppLocalizations"): {
                    "data": [
                        {"id": "bloc-1", "attributes": {"locale": "zh-Hans", "feedbackEmail": "team-fb@example.com"}},
                    ]
                },
            }
        )
        found = asc.fetch_team_fallback_contacts(client, exclude_app_id="app-target")
        self.assertEqual(
            found,
            {
                "contactFirstName": "SampleFirst",
                "contactLastName": "SampleLast",
                "contactEmail": "team-review@example.com",
                "contactPhone": "+8613900001234",
                "feedbackEmail": "team-fb@example.com",
            },
        )
        self.assertFalse(any(p.startswith("/apps/app-target/") for _, p, _ in client.calls))

    def test_sync_beta_metadata_precedence_and_email_crossfill(self) -> None:
        client = _StubASCClient(
            {
                ("GET", "/apps?filter"): {"data": [{"id": "app1", "attributes": {"bundleId": "app.chimmo"}}]},
                ("GET", "/apps?limit=50"): {
                    "data": [
                        {"id": "app1", "attributes": {"bundleId": "app.chimmo"}},
                        {"id": "app2", "attributes": {"bundleId": "app.other"}},
                    ]
                },
                ("GET", "/apps/app1/betaAppLocalizations"): {
                    "data": [
                        {"id": "loc-zh", "attributes": {"locale": "zh-Hans", "feedbackEmail": ""}},
                        {"id": "loc-en", "attributes": {"locale": "en-US", "feedbackEmail": ""}},
                    ]
                },
                ("GET", "/apps/app1/betaAppReviewDetail"): {
                    "data": {
                        "id": "rev1",
                        "attributes": {
                            "contactFirstName": "ExistingTargetFirst",
                        },
                    }
                },
                ("GET", "/apps/app2/betaAppReviewDetail"): {
                    "data": {
                        "id": "rev2",
                        "attributes": {
                            "contactFirstName": "FallbackTeamFirst",
                            "contactLastName": "FallbackTeamLast",
                            "contactPhone": "+8613700009999",
                        },
                    }
                },
                ("GET", "/apps/app2/appStoreVersions?limit=5&include=appStoreReviewDetail"): {"data": [], "included": []},
                ("GET", "/apps/app2/betaAppLocalizations"): {"data": []},
                ("PATCH", "/betaAppLocalizations/loc-zh"): {"data": {}},
                ("PATCH", "/betaAppLocalizations/loc-en"): {"data": {}},
                ("PATCH", "/betaAppReviewDetails/rev1"): {"data": {"id": "rev1"}},
            }
        )
        asc.sync_beta_metadata(
            client,
            bundle_id="app.chimmo",
            version="2.2.0",
            feedback_email="explicit-fb@example.com",
            strict=True,
        )
        zh_patch = next(b for m, p, b in client.calls if m == "PATCH" and p == "/betaAppLocalizations/loc-zh")
        self.assertEqual(zh_patch["data"]["attributes"]["feedbackEmail"], "explicit-fb@example.com")
        rev_patch = next(b for m, p, b in client.calls if m == "PATCH" and p == "/betaAppReviewDetails/rev1")
        attrs = rev_patch["data"]["attributes"]
        self.assertEqual(attrs["contactFirstName"], "ExistingTargetFirst")
        self.assertEqual(attrs["contactLastName"], "FallbackTeamLast")
        self.assertEqual(attrs["contactPhone"], "+8613700009999")
        self.assertEqual(attrs["contactEmail"], "explicit-fb@example.com")
        self.assertFalse(any(p == "/betaAppReviewSubmissions" for _, p, _ in client.calls))

    def test_team_contact_and_sync_logs_emit_zero_pii(self) -> None:
        pii_values = [
            "SecretFirstNamePII",
            "SecretLastNamePII",
            "+8613987654321",
            "secret-contact-pii@example.com",
            "secret-feedback-pii@example.com",
        ]
        client = _StubASCClient(
            {
                ("GET", "/apps?filter"): {"data": [{"id": "app1", "attributes": {"bundleId": "app.chimmo"}}]},
                ("GET", "/apps?limit=50"): {
                    "data": [
                        {"id": "app1", "attributes": {"bundleId": "app.chimmo"}},
                        {"id": "app2", "attributes": {"bundleId": "app.other"}},
                    ]
                },
                ("GET", "/apps/app1/betaAppLocalizations"): {
                    "data": [
                        {"id": "loc-zh", "attributes": {"locale": "zh-Hans"}},
                        {"id": "loc-en", "attributes": {"locale": "en-US"}},
                    ]
                },
                ("GET", "/apps/app1/betaAppReviewDetail"): {"data": {"id": "rev1", "attributes": {}}},
                ("GET", "/apps/app2/betaAppReviewDetail"): {
                    "data": {
                        "id": "rev2",
                        "attributes": {
                            "contactFirstName": "SecretFirstNamePII",
                            "contactLastName": "SecretLastNamePII",
                            "contactEmail": "secret-contact-pii@example.com",
                            "contactPhone": "+8613987654321",
                        },
                    }
                },
                ("GET", "/apps/app2/betaAppLocalizations"): {
                    "data": [{"id": "l2", "attributes": {"locale": "zh-Hans", "feedbackEmail": "secret-feedback-pii@example.com"}}]
                },
                ("PATCH", "/betaAppLocalizations/loc-zh"): {"data": {}},
                ("PATCH", "/betaAppLocalizations/loc-en"): {"data": {}},
                ("PATCH", "/betaAppReviewDetails/rev1"): {"data": {"id": "rev1"}},
            }
        )
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            asc.sync_beta_metadata(client, bundle_id="app.chimmo", version="2.2.0", strict=True)
        out = buf.getvalue()
        for val in pii_values:
            self.assertNotIn(val, out)

    @staticmethod
    def _headers(mapping: dict[str, str]) -> Message:
        msg = Message()
        for k, v in mapping.items():
            msg[k] = v
        return msg


if __name__ == "__main__":
    unittest.main()
