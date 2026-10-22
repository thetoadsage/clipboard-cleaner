#!/usr/bin/env python3
"""
Maintainer-only tool. NOT run by the app, NOT called at build time.

Fetches the ClearURLs rule catalog (github.com/ClearURLs/Rules, LGPL-3.0),
keeps only the parts relevant to local, automatic query-parameter removal
(the `rules` arrays with their URL patterns and exceptions), and writes a
compact resource file in this project's own schema:

    Sources/ClipboardCleanerCore/Resources/tracking-rules.json

Deliberately dropped from the upstream data: `rawRules` (regex over the
whole URL), `redirections`/`forceRedirection` (unwrap embedded URLs -- a
different feature), `completeProvider` (block a URL outright), and
`referralMarketing` (params like bare `ref`/`referrer` that ClearURLs itself
treats as optional/off by default, since they're often legitimate).

Run this occasionally by hand to refresh the catalog:

    python3 scripts/update_tracking_rules.py

It requires network access; the generated JSON is committed to the repo and
is the only thing the app reads at runtime.

The local uassets-reviewed-rules.json snapshot (GPL-3.0) is validated and
included on every refresh. It is deliberately curated, not a filter parser.
"""
from __future__ import annotations

import json
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

COMMIT_API_URL = "https://api.github.com/repos/ClearURLs/Rules/commits/master"
RULES_URL_TEMPLATE = "https://raw.githubusercontent.com/ClearURLs/Rules/{sha}/data.min.json"
REVIEWED_RULES_PATH = Path(__file__).with_name("uassets-reviewed-rules.json")
# Match TrackingRuleCatalog's runtime limits so an update cannot produce a
# resource the app would reject as oversized.
MAX_PATTERN_BYTES = 500
MAX_PATTERN_COUNT = 20_000

# Hand-maintained, NOT derived from ClearURLs -- a small number of
# well-known, unambiguous global tracking parameters not yet present in the
# upstream catalog as of this writing (e.g. Google Ads' newer click-id
# params, siblings of the already-covered `gclid`). Kept separate from the
# fetched data so provenance/attribution stays unambiguous. Extend
# sparingly and only for parameters that are safe to strip on any domain.
LOCAL_GLOBAL_ADDITIONS = ["wbraid", "gbraid", "gclsrc"]
# Hand-maintained, site-specific rules for parameters that are unambiguous
# tracking/share noise on a reviewed domain but unsafe to remove globally.
LOCAL_DOMAIN_ADDITIONS = {
    "z-lib.gd": ["dsource"],
    # User-reported reel share token; keep this name scoped to the mirror.
    "kkinstagram.com": ["mdxt"],
    # User-reported Instagram reel share token.
    "instagram.com": ["dlrf"],
}
OUTPUT_PATH = (
    Path(__file__).resolve().parent.parent
    / "Sources"
    / "ClipboardCleanerCore"
    / "Resources"
    / "tracking-rules.json"
)

PARAM_PREFIX_RE = re.compile(r"^\(\?:%3F\)\?")
# Explicitly reviewed host expressions that cannot be read as literal
# domains. Keep the entire expression; never extract domain-like fragments.
REVIEWED_HOST_EXPRESSIONS = {
    r"(youtube\.com|youtu\.be)",
    r"(?:yandex(?:\.[a-z]{2,}){1,}|ya\.ru)",
    r"(?:accounts\.)?firefox\.com",
    r"(?:support\.)?mozilla\.org",
    r"nikkei\.co(?:m|\.jp)",
    r"weibo\.(cn|com)",
    r"mercadoli[bv]re\.com",
    r"airbnb\.(com|ae|ca|co\.in|co\.nz|co\.uk|co\.za|com\.au|com\.mt|com\.sg|de|gy|ie)",
    r"shopee\.(com|co\.th|tw)",
    r"lazada\.(com|co\.th|co\.id|com\.my|com\.ph|sg|vn)",
}
REVIEWED_PATH_EXPRESSIONS = {
    "", r"/s\?", "/learning", r"/ClearUrls/void/index\.html",
    r"/void/index\.html", r"/search/\?",
}


def scoped_url_pattern(pattern: str) -> str:
    """Accept only reviewed URL shapes and enforce an authority boundary.

    Patterns stay whole, including path restrictions. Unknown expressions
    abort regeneration rather than widening scope or silently losing hosts.
    """
    normalized = pattern.replace(r"\/", "/")
    if normalized.startswith("^https?://"):
        remainder = normalized[len("^https?://"):]
    elif normalized == r"https?://([a-z0-9-.]*\.)shutterstock\.com":
        return r"^https?://(?:[a-z0-9-]+\.)+shutterstock\.com(?::[0-9]+)?(?=[/?#]|$)"
    else:
        raise ValueError(f"unsupported URL pattern: {pattern!r}")
    host, separator, tail = remainder.partition("/")
    path = separator + tail
    prefix = r"(?:[a-z0-9-]+\.)*?"
    subdomains = prefix if host.startswith(prefix) else ""
    body = host[len(subdomains):]
    if body in REVIEWED_HOST_EXPRESSIONS:
        safe_host = body
    elif re.fullmatch(r"[a-z0-9-]+(?:(?:\\\.|\.)[a-z0-9-]+)+", body.replace(r"\-", "-")):
        safe_host = re.escape(body.replace(r"\.", ".").replace(r"\-", "-"))
    elif re.fullmatch(r"[a-z0-9-]+(?:\\\.[a-z0-9-]+)*\(\?:\\\.\[a-z\]\{2,\}\)\{1,\}", body):
        safe_host = body
    else:
        raise ValueError(f"unsupported host pattern: {body!r}")
    if path not in REVIEWED_PATH_EXPRESSIONS:
        raise ValueError(f"unsupported path pattern: {path!r}")
    if path and not path.endswith(r"\?"):
        path += r"(?=[/?#]|$)"
    return "^https?://" + subdomains + "(?:" + safe_host + r")(?::[0-9]+)?(?=[/?#]|$)" + path


def clean_rule_pattern(pattern: str) -> str:
    """Strip the `(?:%3F)?` prefix ClearURLs uses for its raw-query-string
    matching; irrelevant here since we only match against parsed query item
    names, which never contain that literal."""
    return PARAM_PREFIX_RE.sub("", pattern)


def fetch_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": "clipboard-cleaner-rule-updater"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read())


def fetch_pinned_upstream() -> tuple[str, dict]:
    """Resolve master once, then fetch rules from that immutable commit."""
    commit = fetch_json(COMMIT_API_URL)
    commit_sha = commit.get("sha") if isinstance(commit, dict) else None
    if not isinstance(commit_sha, str) or not re.fullmatch(r"[0-9a-f]{40}", commit_sha):
        raise ValueError("ClearURLs commit API returned no valid 40-character SHA")

    rules_url = RULES_URL_TEMPLATE.format(sha=commit_sha)
    print(f"Fetching {rules_url} ...")
    return commit_sha, fetch_json(rules_url)


def validate_upstream_schema(data: object) -> dict:
    if not isinstance(data, dict) or set(data) != {"providers"}:
        raise ValueError("unexpected ClearURLs top-level schema; expected only 'providers'")
    providers = data["providers"]
    if not isinstance(providers, dict) or not providers:
        raise ValueError("ClearURLs 'providers' must be a non-empty object")

    for name, provider in providers.items():
        if not isinstance(name, str) or not isinstance(provider, dict):
            raise ValueError("every ClearURLs provider must be a named object")
        rules = provider.get("rules", [])
        if not isinstance(rules, list) or not all(isinstance(rule, str) for rule in rules):
            raise ValueError(f"provider {name!r} has a non-string 'rules' array")
        if rules and name != "globalRules" and not isinstance(provider.get("urlPattern"), str):
            raise ValueError(f"provider {name!r} has rules but no string 'urlPattern'")
        if "completeProvider" in provider and not isinstance(provider["completeProvider"], bool):
            raise ValueError(f"provider {name!r} has a non-boolean 'completeProvider'")
        exceptions = provider.get("exceptions", [])
        if not isinstance(exceptions, list) or not all(isinstance(p, str) for p in exceptions):
            raise ValueError(f"provider {name!r} has a non-string 'exceptions' array")

    return providers


def add_reviewed_rules(catalog: dict) -> dict:
    """Include a local, reviewed snapshot; never fetch or interpret uBO filters.

    Preserve overrides win at runtime. Global removals inherit ClearURLs'
    global exceptions, so adding another source cannot bypass those scopes.
    Validate the entire snapshot before the caller replaces the resource.
    """
    reviewed = json.loads(REVIEWED_RULES_PATH.read_text())
    source = reviewed["source"]
    if (source["repository"] != "https://github.com/uBlockOrigin/uAssets"
            or source["license"] != "GPL-3.0"
            or not re.fullmatch(r"[0-9a-f]{40}", source["commit"])):
        raise ValueError("invalid reviewed rule provenance")
    entries = reviewed["parameterRules"]
    if not isinstance(entries, list) or not entries:
        raise ValueError("reviewed parameterRules must be a non-empty array")
    global_exceptions = next(
        (p["exceptions"] for p in catalog["providers"] if p["name"] == "globalRules"), []
    )
    rules = []
    for entry in entries:
        if (not isinstance(entry, dict)
                or set(entry) - {"id", "urlPattern", "namePattern", "valuePattern", "action", "exceptions"}
                or not {"id", "urlPattern", "namePattern", "action", "exceptions"} <= set(entry)
                or entry["action"] not in ("remove", "preserve")
                or not isinstance(entry["exceptions"], list)):
            raise ValueError("invalid reviewed parameter rule")
        rule = dict(entry)
        if rule["action"] == "remove" and rule["urlPattern"] == ".*":
            rule["exceptions"] = list(dict.fromkeys(rule["exceptions"] + global_exceptions))
        patterns = [rule["urlPattern"], rule["namePattern"], *rule["exceptions"]]
        if "valuePattern" in rule:
            patterns.append(rule["valuePattern"])
        for pattern in patterns:
            if not isinstance(pattern, str) or not pattern or len(pattern.encode("utf-8")) > MAX_PATTERN_BYTES:
                raise ValueError("invalid or oversized reviewed pattern")
            re.compile(pattern)
        if rule["urlPattern"] != ".*" and not rule["urlPattern"].startswith("^https?://"):
            raise ValueError("reviewed URL pattern must be anchored to HTTP(S)")
        rules.append(rule)
    patterns = [r for p in catalog["providers"] for r in [p["urlPattern"], *p["exceptions"], *p["rules"]]]
    patterns += catalog["global"] + catalog["localGlobalAdditions"]
    patterns += [r for ruleset in catalog["domains"].values() for r in ruleset]
    patterns += [r for rule in rules for r in [rule["urlPattern"], rule["namePattern"], *rule["exceptions"]]]
    patterns += [rule["valuePattern"] for rule in rules if "valuePattern" in rule]
    if len(patterns) > MAX_PATTERN_COUNT:
        raise ValueError("catalog exceeds runtime pattern count limit")
    catalog["reviewedSource"] = source
    catalog["parameterRules"] = rules
    return catalog


def build_catalog(commit_sha: str, data: object) -> dict:
    providers = validate_upstream_schema(data)
    scoped_providers = []
    for name, provider in providers.items():
        rules = provider.get("rules") or []
        if not rules or provider.get("completeProvider"):
            continue
        cleaned_rules = [clean_rule_pattern(r) for r in rules]
        if name == "globalRules":
            if provider.get("urlPattern") != ".*":
                raise ValueError("unexpected globalRules URL pattern")
            url_pattern = ".*"
        else:
            url_pattern = scoped_url_pattern(provider["urlPattern"])
        exceptions = provider.get("exceptions", [])
        for pattern in [url_pattern, *exceptions, *cleaned_rules]:
            if len(pattern.encode("utf-8")) > MAX_PATTERN_BYTES:
                raise ValueError(f"oversized pattern in provider {name!r}")
            re.compile(pattern, re.IGNORECASE)
        scoped_providers.append({
            "name": name, "urlPattern": url_pattern,
            "exceptions": exceptions, "rules": cleaned_rules,
        })

    pattern_count = len(LOCAL_GLOBAL_ADDITIONS) + sum(map(len, LOCAL_DOMAIN_ADDITIONS.values()))
    pattern_count += sum(1 + len(p["exceptions"]) + len(p["rules"]) for p in scoped_providers)
    if pattern_count > MAX_PATTERN_COUNT:
        raise ValueError("catalog exceeds runtime pattern count limit")

    return add_reviewed_rules({
        "source": "Derived from ClearURLs/Rules (https://github.com/ClearURLs/Rules), LGPL-3.0",
        "sourceCommit": commit_sha,
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "global": [],
        "localGlobalAdditionsNote": (
            "Hand-maintained entries below are NOT derived from ClearURLs; "
            "see LOCAL_GLOBAL_ADDITIONS in scripts/update_tracking_rules.py."
        ),
        "localGlobalAdditions": LOCAL_GLOBAL_ADDITIONS,
        "localDomainAdditionsNote": (
            "Hand-maintained entries below are NOT derived from ClearURLs; "
            "they are reviewed for the named domain only."
        ),
        "localDomainAdditions": LOCAL_DOMAIN_ADDITIONS,
        "domains": LOCAL_DOMAIN_ADDITIONS,
        "providers": sorted(scoped_providers, key=lambda p: p["name"]),
    })


def main() -> int:
    commit_sha, data = fetch_pinned_upstream()
    output = build_catalog(commit_sha, data)
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n")

    print(f"Wrote {OUTPUT_PATH}")
    print(f"  scoped providers: {len(output['providers'])}")
    print(f"  reviewed parameter rules: {len(output['parameterRules'])}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
