import Foundation

/// Recognizes a single displayed URL in a small, inert HTML fragment.
/// XML parsing never renders HTML or resolves external resources. Anything
/// outside the supported fragment shape remains untouched on the clipboard.
enum URLOnlyHTML {
    static let maxHTMLBytes = 65_536

    static func clean(_ html: String, original: String, cleaned: String) -> String? {
        guard isSingleURL(html, matching: original) else { return nil }
        let rewritten = html
            .replacingOccurrences(of: escaped(original), with: escaped(cleaned))
            .replacingOccurrences(of: original, with: cleaned)
        // Reject unfamiliar entity encodings rather than leaving a stale
        // destination in one representation of an otherwise cleaned copy.
        return isSingleURL(rewritten, matching: cleaned) ? rewritten : nil
    }

    private static func escaped(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    private static func isSingleURL(_ html: String, matching url: String) -> Bool {
        guard html.utf8.count <= maxHTMLBytes else { return false }
        let withoutComments = html.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        guard !withoutComments.contains("<!"), !withoutComments.contains("<?") else { return false }
        // Chromium emits HTML's void <meta charset> element without a slash.
        // Normalize only that element for the conservative XML parser.
        let normalized = withoutComments.replacingOccurrences(
            of: "(?i)<meta\\b([^>]*?)(?<!/)>", with: "<meta$1/>", options: .regularExpression
        )
        let parser = XMLParser(data: Data(("<clipboard-fragment>" + normalized + "</clipboard-fragment>").utf8))
        let validator = FragmentValidator(expectedURL: url)
        parser.delegate = validator
        parser.shouldResolveExternalEntities = false
        return parser.parse() && validator.isValid
    }

    private final class FragmentValidator: NSObject, XMLParserDelegate {
        let expectedURL: String
        var anchorCount = 0
        var text = ""
        var rejected = false
        private let allowedTags: Set<String> = [
            "clipboard-fragment", "html", "head", "body", "a", "span",
            "div", "p", "b", "strong", "i", "em", "u", "s", "code", "font", "meta",
        ]

        init(expectedURL: String) { self.expectedURL = expectedURL }

        var isValid: Bool {
            !rejected && anchorCount == 1 && text.trimmingCharacters(in: .whitespacesAndNewlines) == expectedURL
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
            let tag = elementName.lowercased()
            guard allowedTags.contains(tag) else { rejected = true; parser.abortParsing(); return }
            if tag == "meta", attributes.keys.contains(where: { $0.lowercased() != "charset" }) {
                rejected = true
                parser.abortParsing()
            }
            if tag == "a" {
                anchorCount += 1
                guard anchorCount == 1, attributes["href"] == expectedURL else {
                    rejected = true
                    parser.abortParsing()
                    return
                }
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
    }
}
