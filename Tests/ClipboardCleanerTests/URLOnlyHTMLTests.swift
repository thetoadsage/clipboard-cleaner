import Foundation
import Testing
@testable import ClipboardCleaner

struct URLOnlyHTMLTests {
    private let original = "https://example.com/?q=keep&utm_source=share"
    private let cleaned = "https://example.com/?q=keep"

    @Test func preservesURLFormattingAndRewritesDestinationTitleAndLabel() {
        let html = "<meta charset='utf-8'><a class='link' href='https://example.com/?q=keep&amp;utm_source=share' title='https://example.com/?q=keep&amp;utm_source=share'><span style='color: blue'>https://example.com/?q=keep&amp;utm_source=share</span></a>"
        let expected = "<meta charset='utf-8'><a class='link' href='https://example.com/?q=keep' title='https://example.com/?q=keep'><span style='color: blue'>https://example.com/?q=keep</span></a>"
        #expect(URLOnlyHTML.clean(html, original: original, cleaned: cleaned) == expected)
    }

    @Test func preservesEncodedFunctionalParametersAndFragmentComments() {
        let before = "https://example.com/?q=one&id=2&utm_source=share"
        let after = "https://example.com/?q=one&id=2"
        let html = "<!--StartFragment--><a href='https://example.com/?q=one&amp;id=2&amp;utm_source=share'>https://example.com/?q=one&amp;id=2&amp;utm_source=share</a><!--EndFragment-->"
        #expect(URLOnlyHTML.clean(html, original: before, cleaned: after) == "<!--StartFragment--><a href='https://example.com/?q=one&amp;id=2'>https://example.com/?q=one&amp;id=2</a><!--EndFragment-->")
    }

    @Test(arguments: [
        "<a href='$URL'>A descriptive title</a>",
        "<a href='https://different.example/'>$URL</a>",
        "<a href='$URL'>$URL</a><p>Additional content</p>",
        "<a href='$URL'>$URL</a><a href='$URL'></a>",
        "<a href='$URL'>$URL<img src='https://example.com/image.png'/></a>",
        "<a href='$URL'>$URL<script>anything()</script></a>",
        "<a href='$URL'>$URL<svg/></a>",
        "<meta http-equiv='refresh' content='0;url=https://example.com'/><a href='$URL'>$URL</a>",
        "<!DOCTYPE html><a href='$URL'>$URL</a>",
        "<?instruction?><a href='$URL'>$URL</a>",
        "<a href='$URL'>$URL",
        "<span>$URL</span>",
    ])
    func rejectsOtherContentOrAmbiguousFragments(template: String) {
        let html = template.replacingOccurrences(of: "$URL", with: original.replacingOccurrences(of: "&", with: "&amp;"))
        #expect(URLOnlyHTML.clean(html, original: original, cleaned: cleaned) == nil)
    }

    @Test func rejectsOversizedHTMLBeforeParsing() {
        #expect(URLOnlyHTML.clean(String(repeating: "x", count: URLOnlyHTML.maxHTMLBytes + 1), original: original, cleaned: cleaned) == nil)
    }

    @Test func unfamiliarEntityEncodingNeverLeavesAnOldDestination() {
        let encoded = original.replacingOccurrences(of: "&", with: "&#38;")
        #expect(URLOnlyHTML.clean("<a href='\(encoded)'>\(encoded)</a>", original: original, cleaned: cleaned) == nil)
    }
}
