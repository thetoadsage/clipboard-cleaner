import Foundation
import Testing
@testable import ClipboardCleanerCore

struct WhitespaceURLTests {
    private let original = "https://www.instagram.com/reel/Dd27vP1NOKp/?dlrf=aTlxbHBnOXhucGlq"
    private let cleaned = "https://www.instagram.com/reel/Dd27vP1NOKp/"

    @Test(arguments: [" ", "\n", "\n\n", "\r\n", "\t", "\u{00A0}", " \n\t"])
    func cleansSingleURLWithSurroundingWhitespace(padding: String) {
        for input in [padding + original, original + padding, padding + original + padding] {
            let result = URLCleaner.cleanWithDetails(input)
            #expect(result.cleaned == cleaned)
            #expect(result.parametersRemoved == 1)
            #expect(URLCleaner.cleanWithDetails(result.cleaned) == .init(cleaned: cleaned, parametersRemoved: 0))
        }
    }

    @Test func preservesFunctionalQueryEncodingAndFragment() {
        let result = URLCleaner.cleanWithDetails(" \nhttps://instagram.com/reel/abc/?next=%2fwatch%3Fx%3D1&dlrf=share&tag=a&tag=b#part%23two\t")
        #expect(result.cleaned == "https://instagram.com/reel/abc/?next=%2fwatch%3Fx%3D1&tag=a&tag=b#part%23two")
        #expect(result.parametersRemoved == 1)
    }

    @Test func cleansPaddedRedirectAndCanonicalURL() {
        let result = URLCleaner.cleanWithDetails(" \nhttps://duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com%2F%3Futm_source%3Dtest&rut=share\n")
        #expect(result.cleaned == "https://example.com/")
        #expect(result.parametersRemoved == 3)
        #expect(URLCleaner.clean(" https://www.amazon.com/product/dp/B08XYZ1234?tag=share ") == "https://www.amazon.com/dp/B08XYZ1234")
    }

    @Test(arguments: [
        " \nhttps://example.com/ \n",
        " \nhttps://example.com/?keep=%2F \n",
        " \nhttps://example.com/?utm_source=test extra text\n",
        " \nhttps://example.com/?utm_source=test\nhttps://other.example/ \n",
        " \nRead https://example.com/?utm_source=test \n",
        " \njust text \n",
        " \nftp://example.com/?utm_source=test \n",
        " \nhttps:// \n",
        " \n\t",
    ])
    func preservesUnchangedURLsAndOtherText(input: String) {
        #expect(URLCleaner.cleanWithDetails(input) == .init(cleaned: input, parametersRemoved: 0))
    }

    @Test func sizeLimitIncludesWhitespace() {
        let input = String(repeating: " ", count: URLCleaner.maxInputLengthBytes) + original
        #expect(URLCleaner.clean(input) == input)
    }
}
