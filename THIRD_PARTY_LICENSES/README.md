# Third-party data

## ClearURLs/Rules

`Sources/ClipboardCleanerCore/Resources/tracking-rules.json` is derived from
the [ClearURLs/Rules](https://github.com/ClearURLs/Rules) catalog, licensed
under the [GNU Lesser General Public License v3.0](ClearURLs-Rules-LGPL-3.0.txt).

The `rules` field (query parameter names/patterns to strip), `urlPattern`,
and `exceptions` are re-expressed in this project's own JSON schema.
Provider path restrictions and exceptions remain separate; host patterns
are validated and bounded to prevent matching unrelated domains. Not
included: `rawRules`, `redirections`/`forceRedirection`, providers with
`completeProvider: true`, or `referralMarketing` — see
`scripts/update_tracking_rules.py` for the exact conversion logic.

The `localGlobalAdditions` and `localDomainAdditions` in
`tracking-rules.json` are hand-maintained by this project and are *not*
derived from ClearURLs. Local domain additions are also emitted in `domains`
for runtime matching.

To refresh the ClearURLs-derived portion of the catalog:

```bash
python3 scripts/update_tracking_rules.py
```

This is a manual maintenance step requiring internet access. The app itself
never makes network requests.

## uBlock Origin uAssets

`scripts/uassets-reviewed-rules.json` contains a curated subset of URL
tracking-removal and preservation rules derived from
[uBlockOrigin/uAssets](https://github.com/uBlockOrigin/uAssets) at commit
`c07a29de87b10d2a6f23be4b1117479ec3cfc87b`, licensed under the
[GNU General Public License v3.0](uAssets-GPL-3.0.txt). This rule data retains
those terms. Its source files are `filters/privacy.txt`,
`filters/privacy-removeparam.txt`, and `filters/annoyances-others.txt`.
The URL-matching formats added to `RedirectUnwrapper.swift` were also
reviewed against these lists; the Swift decoding implementation is original.

Modifications: a small reviewed selection is re-expressed in this project's
JSON schema, host/path scopes are explicit, the Drip `__s` value condition
is narrowed to fully alphanumeric values, and new global removals inherit
the ClearURLs global exceptions. Individual parameter preservation overrides
take priority. No general uBO filter parser, browser scriptlets, network
blocking, or browser-context evaluation is included.

The maintainer updater validates this local snapshot and includes it as
`parameterRules` in `tracking-rules.json`, with source provenance in
`reviewedSource`. It does not fetch uAssets automatically. Re-generating
the ClearURLs section retains this reviewed subset.

App bundles include these attribution notes and license texts in
`Contents/Resources/ThirdPartyLicenses/`.
