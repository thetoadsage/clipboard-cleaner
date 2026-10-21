import Foundation
import Testing
@testable import ClipboardCleanerCore

struct QueryPreservationTests {
    @Test(arguments: [
        ("https://example.com/?q=café&next=%2Fprivate%3Fx%3D1&x=%41&utm_source=test",
         "https://example.com/?q=café&next=%2Fprivate%3Fx%3D1&x=%41"),
        ("HTTPS://EXAMPLE.COM:443/a%2fb?next=a%26b%3Dc%2Fd&flag&empty=&utm_source=test#café%23section",
         "HTTPS://EXAMPLE.COM:443/a%2fb?next=a%26b%3Dc%2Fd&flag&empty=#café%23section"),
        ("https://example.com/?utm_source=test&a=one+two&a=one%20two&a=one%2btwo&literal=x=y",
         "https://example.com/?a=one+two&a=one%20two&a=one%2btwo&literal=x=y"),
        ("https://example.com/?a=1&&utm_source=test&b=2&",
         "https://example.com/?a=1&&b=2&"),
        ("https://example.com/?%75tm_source=test&keep=%252F",
         "https://example.com/?keep=%252F"),
        ("https://example.com/?utm_source&keep=%FF&other=%zz",
         "https://example.com/?keep=%FF&other=%zz"),
    ])
    func keepsSurvivingURLBytes(input: String, expected: String) {
        let result = URLCleaner.cleanWithDetails(input)
        #expect(result.cleaned == expected)
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(expected) == .init(cleaned: expected, parametersRemoved: 0))
    }

    @Test func decodesValuesOnceForConditionalRules() {
        let result = URLCleaner.cleanWithDetails(
            "https://example.com/?q=café&__s=%61bcdef&__s=%2561bcdef&__s=abc%2Ddef&keep=%41"
        )
        #expect(result.cleaned == "https://example.com/?q=café&__s=%2561bcdef&__s=abc%2Ddef&keep=%41")
        #expect(result.parametersRemoved == 1)
    }

    @Test func contextualYouTubeRulesKeepQuerySpellingAndCounts() {
        let result = URLCleaner.cleanWithDetails(
            "https://youtube.com/watch?v=abc&list=RDabc&start_radio=%31&t=%34%32&note=café&next=%2F&si=share#part%23two"
        )
        #expect(result.cleaned == "https://youtube.com/watch?v=abc&t=%34%32&note=café&next=%2F#part%23two")
        #expect(result.parametersRemoved == 3)
    }

    @Test func preservesEncodingAfterUnwrapping() {
        let destination = "https://example.com/?next=%2Fprivate%3Fx%3D1&x=%41&utm_source=test#part%23two"
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        let result = URLCleaner.cleanWithDetails("https://duckduckgo.com/l/?uddg=\(encoded)&rut=tracking")
        #expect(result.cleaned == "https://example.com/?next=%2Fprivate%3Fx%3D1&x=%41#part%23two")
        #expect(result.parametersRemoved == 3)
    }

    @Test func recognizesDelimitersBesideCombiningMarks() {
        let result = URLCleaner.cleanWithDetails(
            "https://example.com/?\u{0301}keep=a&\u{0301}flag&other=\u{0301}value&utm_source=test#\u{0301}section?utm_medium=keep"
        )
        #expect(result.cleaned == "https://example.com/?\u{0301}keep=a&\u{0301}flag&other=\u{0301}value#\u{0301}section?utm_medium=keep")
        #expect(result.parametersRemoved == 1)
    }

    @Test(arguments: [
        "https://example.com/path#part?utm_source=keep",
        "https://example.com/?q=café&next=%2F&flag&empty=#part%23two",
        "https://example.com/?",
        "https://example.com/?&&#fragment",
        "https://app.plex.tv/auth-form/?utm_source=café&next=%2F",
    ])
    func unchangedInputsStayExact(input: String) {
        #expect(URLCleaner.cleanWithDetails(input) == .init(cleaned: input, parametersRemoved: 0))
    }
}
