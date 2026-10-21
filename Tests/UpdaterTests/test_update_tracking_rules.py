import importlib.util
import re
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).parents[2] / "scripts" / "update_tracking_rules.py"
SPEC = importlib.util.spec_from_file_location("update_tracking_rules", SCRIPT_PATH)
updater = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(updater)


class UpdateTrackingRulesTests(unittest.TestCase):
    def test_fetches_commit_before_rules_and_pins_rules_url(self):
        sha = "a" * 40
        calls = []

        def fake_fetch(url):
            calls.append(url)
            return {"sha": sha} if url == updater.COMMIT_API_URL else {"providers": {}}

        with patch.object(updater, "fetch_json", side_effect=fake_fetch):
            actual_sha, data = updater.fetch_pinned_upstream()

        self.assertEqual(actual_sha, sha)
        self.assertEqual(data, {"providers": {}})
        self.assertEqual(
            calls,
            [updater.COMMIT_API_URL, updater.RULES_URL_TEMPLATE.format(sha=sha)],
        )

    def test_rejects_invalid_commit_sha(self):
        with patch.object(updater, "fetch_json", return_value={"sha": "master"}):
            with self.assertRaisesRegex(ValueError, "valid 40-character SHA"):
                updater.fetch_pinned_upstream()

    def test_rejects_changed_top_level_schema(self):
        with self.assertRaisesRegex(ValueError, "top-level schema"):
            updater.validate_upstream_schema({"providers": {}, "schemaVersion": 2})

    def test_rejects_malformed_provider_rules(self):
        data = {"providers": {"example": {"urlPattern": "example", "rules": "utm"}}}
        with self.assertRaisesRegex(ValueError, "non-string 'rules' array"):
            updater.validate_upstream_schema(data)

    def test_country_alternations_keep_brand_and_host_boundary(self):
        patterns = [
            (r"airbnb\.(com|ae|ca|co\.in|co\.nz|co\.uk|co\.za|com\.au|com\.mt|com\.sg|de|gy|ie)", "airbnb.co.uk", "example.co.uk"),
            (r"shopee\.(com|co\.th|tw)", "shopee.co.th", "example.co.th"),
            (r"lazada\.(com|co\.th|co\.id|com\.my|com\.ph|sg|vn)", "lazada.com.my", "example.com.my"),
            (r"mercadoli[bv]re\.com", "mercadolivre.com", "re.com"),
            (r"nikkei\.co(?:m|\.jp)", "nikkei.co.jp", "nikkei.co"),
            (r"weibo\.(cn|com)", "weibo.cn", "example.com"),
        ]
        for expression, good, bad in patterns:
            with self.subTest(expression=expression):
                regex = re.compile(updater.scoped_url_pattern("^https?://(?:[a-z0-9-]+\\.)*?" + expression))
                self.assertRegex("https://www." + good + "/page", regex)
                for host in [bad, good + ".example.com", "not" + good]:
                    self.assertNotRegex("https://" + host + "/page", regex)

    def test_paths_and_literal_dots_are_preserved(self):
        regex = re.compile(updater.scoped_url_pattern(r"^https?://(?:[a-z0-9-]+\.)*?linkedin\.com/learning"))
        self.assertRegex("https://linkedin.com/learning/course", regex)
        self.assertNotRegex("https://linkedin.com/profile?u=123", regex)
        self.assertNotRegex("https://linkedin.com.example.com/learning", regex)
        twitter = updater.scoped_url_pattern(r"^https?://(?:[a-z0-9-]+\.)*?twitter.com")
        self.assertNotRegex("https://twitterXcom/", twitter)

    def test_unsupported_patterns_abort_without_replacing_catalog(self):
        data = {"providers": {"unknown": {"urlPattern": r"^https?://example\.(?:com|.*)", "rules": ["x"]}}}
        with tempfile.TemporaryDirectory() as root:
            output = Path(root) / "catalog.json"
            output.write_text("original")
            with patch.object(updater, "fetch_pinned_upstream", return_value=("a" * 40, data)), patch.object(updater, "OUTPUT_PATH", output):
                with self.assertRaisesRegex(ValueError, "unsupported host pattern"):
                    updater.main()
            self.assertEqual(output.read_text(), "original")
        for pattern in [r"^https?://example\.com/unknown.*", r"^https?://.*"]:
            with self.assertRaisesRegex(ValueError, "unsupported"):
                updater.scoped_url_pattern(pattern)

    def test_provider_exceptions_remain_separate_in_generated_catalog(self):
        exception = r"^https?://example\.com/search"
        data = {"providers": {
            "globalRules": {"urlPattern": ".*", "rules": ["utm_source"], "exceptions": [exception]},
            "site": {"urlPattern": r"^https?://example\.com", "rules": ["keywords"], "exceptions": [exception]},
            "search": {"urlPattern": r"^https?://example\.com/s\?", "rules": ["qid"]},
        }}
        generated = updater.build_catalog("a" * 40, data)
        providers = {p["name"]: p for p in generated["providers"]}
        self.assertEqual(providers["globalRules"]["exceptions"], [exception])
        self.assertEqual(providers["site"]["exceptions"], [exception])
        self.assertEqual(providers["search"]["rules"], ["qid"])
        self.assertEqual(generated["domains"], updater.LOCAL_DOMAIN_ADDITIONS)

    def test_rejects_malformed_or_invalid_exceptions(self):
        for exceptions in ["not-an-array", [123], ["["]]:
            with self.subTest(exceptions=exceptions):
                with self.assertRaises((ValueError, re.error)):
                    updater.build_catalog("a" * 40, {"providers": {"site": {
                        "urlPattern": r"^https?://example\.com", "rules": ["x"], "exceptions": exceptions,
                    }}})

    def test_rejects_patterns_exceeding_runtime_limits(self):
        for rules in [["x" * (updater.MAX_PATTERN_BYTES + 1)], ["x"] * updater.MAX_PATTERN_COUNT]:
            with self.assertRaisesRegex(ValueError, "oversized|count limit"):
                updater.build_catalog("a" * 40, {"providers": {"site": {
                    "urlPattern": r"^https?://example\.com", "rules": rules,
                }}})


if __name__ == "__main__":
    unittest.main()
