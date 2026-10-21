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
