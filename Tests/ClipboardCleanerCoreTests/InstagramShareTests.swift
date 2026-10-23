import Testing
@testable import ClipboardCleanerCore

struct InstagramShareTests {
    @Test func removesPslnFromReportedInstagramURL() {
        let input = "https://www.instagram.com/p/Dez0wJLkqFS/?psln=MXhvMmhocTYxeHpoMQ=="
        let expected = "https://www.instagram.com/p/Dez0wJLkqFS/"
        let result = URLCleaner.cleanWithDetails(input)
        #expect(result.cleaned == expected)
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(result.cleaned).parametersRemoved == 0)
    }

    @Test(arguments: ["instagram.com", "www.instagram.com", "m.instagram.com", "WWW.INSTAGRAM.COM:443"])
    func removesPslnWhilePreservingOtherQuerySpellingAndFragment(host: String) {
        let result = URLCleaner.cleanWithDetails("https://\(host)/p/abc/?next=%2fwatch%3Fx%3D1&PSLN=share&tag=a&tag=b&%70sln=again#photo%23one")
        #expect(result.cleaned == "https://\(host)/p/abc/?next=%2fwatch%3Fx%3D1&tag=a&tag=b#photo%23one")
        #expect(result.parametersRemoved == 2)
    }

    @Test func removesCombinedInstagramShareTokens() {
        let result = URLCleaner.cleanWithDetails("https://www.instagram.com/p/abc/?psln=share&dlrf=share&id=42")
        #expect(result.cleaned == "https://www.instagram.com/p/abc/?id=42")
        #expect(result.parametersRemoved == 2)
    }

    @Test func removesDlrfFromReportedInstagramURL() {
        let input = "https://www.instagram.com/reel/Dd27vP1NOKp/?dlrf=aTlxbHBnOXhucGlq"
        let expected = "https://www.instagram.com/reel/Dd27vP1NOKp/"
        let result = URLCleaner.cleanWithDetails(input)
        #expect(result.cleaned == expected)
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.clean(expected) == expected)
        #expect(URLCleaner.cleanWithDetails(expected).parametersRemoved == 0)
    }

    @Test(arguments: ["instagram.com", "www.instagram.com", "m.instagram.com", "WWW.INSTAGRAM.COM:443"])
    func removesDlrfWhilePreservingOtherQuerySpellingAndFragment(host: String) {
        let result = URLCleaner.cleanWithDetails("https://\(host)/reel/abc/?next=%2fwatch%3Fx%3D1&DLRF=share&tag=a&tag=b&%64lrf=again#video")
        #expect(result.cleaned == "https://\(host)/reel/abc/?next=%2fwatch%3Fx%3D1&tag=a&tag=b#video")
        #expect(result.parametersRemoved == 2)
    }

    @Test func removesMdxtFromReportedKKInstagramURL() {
        let input = "https://www.kkinstagram.com/reel/Dd0RB2qN-_w/?mdxt=MW9pYzFvbnkzbDlhbA=="
        let expected = "https://www.kkinstagram.com/reel/Dd0RB2qN-_w/"
        let result = URLCleaner.cleanWithDetails(input)
        #expect(result.cleaned == expected)
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(expected).parametersRemoved == 0)
        #expect(URLCleaner.clean(expected) == expected)
    }

    @Test(arguments: ["kkinstagram.com", "www.kkinstagram.com", "m.kkinstagram.com", "WWW.KKINSTAGRAM.COM:443"])
    func preservesOtherQuerySpellingAndFragment(host: String) {
        let result = URLCleaner.cleanWithDetails("https://\(host)/reel/abc/?next=%2fwatch%3Fx%3D1&MDXT=share&tag=a&tag=b&mdxt=again#video")
        #expect(result.cleaned == "https://\(host)/reel/abc/?next=%2fwatch%3Fx%3D1&tag=a&tag=b#video")
        #expect(result.parametersRemoved == 2)
    }

    @Test(arguments: [
        "https://example.com/p/abc/?psln=keep",
        "https://notinstagram.com/p/abc/?psln=keep",
        "https://instagram.com.example.com/p/abc/?psln=keep",
        "https://instagramXcom/p/abc/?psln=keep",
        "https://kkinstagram.com/p/abc/?psln=keep",
        "https://instagram.com/p/abc/?psln_extra=keep&custom=keep",
        "https://example.com/reel/abc/?dlrf=keep",
        "https://notinstagram.com/reel/abc/?dlrf=keep",
        "https://instagram.com.example.com/reel/abc/?dlrf=keep",
        "https://instagramXcom/reel/abc/?dlrf=keep",
        "https://instagram.com/reel/abc/?dlrf_extra=keep&custom=keep",
        "https://example.com/reel/abc/?mdxt=keep",
        "https://notkkinstagram.com/reel/abc/?mdxt=keep",
        "https://kkinstagram.com.example.com/reel/abc/?mdxt=keep",
        "https://kkinstagramXcom/reel/abc/?mdxt=keep",
        "https://kkinstagram.com/reel/abc/?mdxt_extra=keep&custom=keep",
    ])
    func preservesParametersOutsideExactRule(input: String) {
        #expect(URLCleaner.clean(input) == input)
    }
}
