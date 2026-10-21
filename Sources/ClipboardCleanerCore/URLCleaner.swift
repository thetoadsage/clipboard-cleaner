import Foundation

/// Cleans a URL through three layers, in order:
///
/// 1. `RedirectUnwrapper` -- locally unwraps a small set of known
///    redirect/wrapper links (e.g. Facebook share links, Google result
///    redirects) whose destination is embedded in their own query string.
/// 2. `CanonicalURLRules` -- explicit, opt-in rewrites to a minimal
///    canonical form for a small set of well-known product pages (e.g.
///    AliExpress, Amazon). Only applies when host *and* path confidently
///    match; otherwise falls through untouched.
/// 3. `TrackingRuleCatalog` -- the default: removes known tracking query
///    parameters by name, honoring reviewed value conditions and preservation
///    overrides, leaving everything else (including URLs that
///    didn't match layer 1 or 2 at all) untouched. This is what keeps the
///    app safe for the long tail of sites it hasn't specifically reviewed.
///
/// Non-URL text passes through every layer unchanged.
public enum URLCleaner {

    /// The result of a cleaning operation, including how many query
    /// parameters were actually removed (by canonical rewriting or
    /// blocklist filtering) -- used only for the aggregate statistics
    /// counters. Never carries the URL's content beyond the returned
    /// `cleaned` string itself; `parametersRemoved` is just a count.
    public struct CleaningResult: Equatable {
        public let cleaned: String
        public let parametersRemoved: Int
    }

    /// Clipboard content longer than this is returned unchanged without any
    /// parsing, unwrapping, or regex matching. Defense-in-depth against
    /// pathological-input CPU cost (e.g. regex worst cases) and simply
    /// correct behavior on its own merits: no real URL is anywhere near
    /// this long, and large clipboard content is essentially always
    /// non-URL text (a document, code, etc.) that must be left untouched
    /// anyway. Measured in UTF-8 bytes, not `String.count`, to avoid
    /// grapheme-cluster segmentation cost on adversarial Unicode before the
    /// length check itself has even run.
    static let maxInputLengthBytes = 8192

    /// Returns a cleaned version of `input`. If `input` is not a recognizable
    /// http/https URL, or has nothing to remove, `input` is returned
    /// unchanged (a redirect-unwrap on its own counts as a change).
    public static func clean(_ input: String) -> String {
        cleanWithDetails(input).cleaned
    }

    /// Same cleaning behavior as `clean(_:)`, but also reports how many
    /// query parameters were removed -- used to drive the statistics
    /// counters. This includes parameters discarded by redirect-unwrapping
    /// (every query parameter on a wrapper URL that got replaced by its
    /// destination -- not just the one holding the destination), by
    /// canonical rewriting, and by blocklist filtering. `parametersRemoved`
    /// is 0 only when nothing at all was stripped.
    public static func cleanWithDetails(_ input: String) -> CleaningResult {
        guard input.utf8.count <= maxInputLengthBytes else {
            return CleaningResult(cleaned: input, parametersRemoved: 0)
        }

        let unwrapped = RedirectUnwrapper.fullyUnwrap(input)
        let candidate = unwrapped.result

        guard let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host != nil,
            let components = URLComponents(string: candidate)
        else {
            return CleaningResult(cleaned: input, parametersRemoved: 0)
        }

        if let canonical = CanonicalURLRules.canonicalize(url) {
            // Canonical rules always drop the entire query string, so every
            // query item the URL had (if any) counts as removed, plus
            // whatever redirect-unwrapping already discarded.
            let removedCount = (components.queryItems?.count ?? 0) + unwrapped.parametersRemoved
            return CleaningResult(cleaned: canonical, parametersRemoved: removedCount)
        }

        guard let query = RawQuery(candidate) else {
            return CleaningResult(cleaned: candidate, parametersRemoved: unwrapped.parametersRemoved)
        }
        let originalItems = query.items

        let host = url.host?.lowercased()
        let applicableRules = TrackingRuleCatalog.shared.rules(for: host, url: candidate)
        // Some Shorts share links use `is` instead of `si`. Scope this
        // additional name to a Shorts video so unrelated uses survive.
        let pathParts = components.path.split(separator: "/", omittingEmptySubsequences: false)
        let removesShortsShareParameter = host.map { HostMatching.matches(host: $0, domain: "youtube.com") } == true
            && pathParts.count == 3
            && pathParts[1] == "shorts"
            && !pathParts[2].isEmpty
        let isYoutubeVideo = host.map { HostMatching.matches(host: $0, domain: "youtube.com") } == true
            && components.path == "/watch"
            && originalItems.contains { $0.name == "v" && !($0.value ?? "").isEmpty }
        // A radio launch carries generated playlist context rather than an
        // explicitly selected playlist. Require both radio markers and a
        // watch URL with a video before dropping that context; ordinary
        // playlists and timestamps must survive.
        let removesRadioContext = isYoutubeVideo
            && originalItems.contains { $0.name == "list" && ($0.value ?? "").hasPrefix("RD") }
            && originalItems.contains { $0.name == "start_radio" && $0.value == "1" }
        // FL playlist context and its position are unnecessary when sharing
        // the individual video. Keep other playlists and standalone indexes.
        let removesFavoritesContext = isYoutubeVideo && originalItems.contains {
            $0.name == "list" && ($0.value ?? "").hasPrefix("FL") && ($0.value ?? "").count > 2
        }
        let filteredItems = originalItems.filter {
            !applicableRules.contains($0.name, value: $0.value)
                && !(removesShortsShareParameter && $0.name.lowercased() == "is")
                && !(removesRadioContext && ($0.name == "list" || $0.name == "start_radio"))
                && !(removesFavoritesContext && ($0.name == "list" || $0.name == "index"))
        }

        guard filteredItems.count != originalItems.count else {
            return CleaningResult(cleaned: candidate, parametersRemoved: unwrapped.parametersRemoved)
        }

        let removedCount = (originalItems.count - filteredItems.count) + unwrapped.parametersRemoved
        let remainingQuery = filteredItems.isEmpty ? "" : "?" + filteredItems.map(\.raw).joined(separator: "&")
        return CleaningResult(
            cleaned: query.prefix + remainingQuery + query.fragment,
            parametersRemoved: removedCount
        )
    }

    /// Foundation still validates the URL and supplies host/path scope above.
    /// Parse the original query separately: serializing decoded query items
    /// can change escapes in values the cleaner has no reason to touch, and
    /// literal Unicode can cause Foundation to escape an existing '%' again.
    /// Only decoded names/values are used for matching; output uses raw pairs.
    private struct RawQuery {
        struct Item {
            let raw: String
            let name: String
            let value: String?

            init(_ bytes: Substring.UTF8View.SubSequence) {
                raw = String(decoding: bytes, as: UTF8.self)
                let equals = bytes.firstIndex(of: 0x3D) ?? bytes.endIndex
                let rawName = String(decoding: bytes[..<equals], as: UTF8.self)
                name = rawName.removingPercentEncoding ?? rawName
                if equals == bytes.endIndex {
                    value = nil
                } else {
                    let rawValue = String(decoding: bytes[bytes.index(after: equals)...], as: UTF8.self)
                    value = rawValue.removingPercentEncoding ?? rawValue
                }
            }
        }

        let prefix: String
        let fragment: String
        let items: [Item]

        init?(_ input: String) {
            // ASCII delimiter bytes stay recognizable even when followed by
            // combining marks in the same Swift Character. Never split on a
            // percent-encoded delimiter or a '?' inside the fragment.
            let bytes = input.utf8
            let hash = bytes.firstIndex(of: 0x23) ?? bytes.endIndex
            guard let question = bytes[..<hash].firstIndex(of: 0x3F) else { return nil }
            prefix = String(decoding: bytes[..<question], as: UTF8.self)
            fragment = String(decoding: bytes[hash...], as: UTF8.self)
            items = bytes[bytes.index(after: question)..<hash]
                .split(separator: 0x26, omittingEmptySubsequences: false)
                .map(Item.init)
        }
    }

    /// Returns true if `input` looks like a URL this cleaner would inspect
    /// (used to decide whether clipboard text should be touched at all).
    public static func isURL(_ input: String) -> Bool {
        guard let url = URL(string: input), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return (scheme == "http" || scheme == "https") && url.host != nil
    }
}
