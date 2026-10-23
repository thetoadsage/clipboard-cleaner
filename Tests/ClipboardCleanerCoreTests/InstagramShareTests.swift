import Testing
@testable import ClipboardCleanerCore

struct InstagramShareTests {
    @Test func removesRpxtFromReportedInstagramURL() {
        let input = "https://www.instagram.com/reel/De1nYcvFGaP/?rpxt=Y2xlMnp5MzkwaTZ0"
        let expected = "https://www.instagram.com/reel/De1nYcvFGaP/"
        let result = URLCleaner.cleanWithDetails(input)
        #expect(result.cleaned == expected)
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(result.cleaned) == .init(cleaned: expected, parametersRemoved: 0))
        #expect(URLCleaner.clean(" \n" + input + "\t") == expected)
    }

    @Test(arguments: ["rpxt", "obrf", "vrfl", "cplk", "mdxt", "igsi", "si", "stkn"])
    func removesReviewedShareNamesOnlyOnInstagram(name: String) {
        for host in ["instagram.com", "www.instagram.com", "m.instagram.com", "WWW.INSTAGRAM.COM:443"] {
            // Keep content selectors, raw escapes, repeated values and unknown
            // four-letter names: a name's length is not evidence of tracking.
            let kept = "img_index=2&comment_id=123&open_comments=1&story_media_id=456&code=auth&lang=en&next=%2fwatch%3Fx%3D1&tag=a&tag=b"
            let encodedName = "%" + String(name.utf8.first!, radix: 16) + name.dropFirst()
            let result = URLCleaner.cleanWithDetails("https://\(host)/p/abc/?\(name.uppercased())=share&\(kept)&\(encodedName)=again&\(name)#photo%23one")
            let expected = "https://\(host)/p/abc/?\(kept)#photo%23one"
            #expect(result.cleaned == expected)
            #expect(result.parametersRemoved == 3)
            #expect(URLCleaner.cleanWithDetails(expected) == .init(cleaned: expected, parametersRemoved: 0))
        }
        for host in ["example.com", "notinstagram.com", "instagram.com.example.com", "instagramXcom"] {
            let input = "https://\(host)/p/abc/?\(name)=keep"
            #expect(URLCleaner.cleanWithDetails(input) == .init(cleaned: input, parametersRemoved: 0))
        }
        let lookalikes = "https://instagram.com/p/abc/?\(name)_extra=keep&prefix_\(name)=keep"
        #expect(URLCleaner.clean(lookalikes) == lookalikes)
    }

    @Test func cleansCombinedKnownInstagramShareParameters() {
        let result = URLCleaner.cleanWithDetails("https://instagram.com/reel/abc/?igshid=a&igsh=b&ig_rid=c&dlrf=d&psln=e&rpxt=f&obrf=g&vrfl=h&cplk=i&mdxt=j&igsi=k&si=l&stkn=m&utm_source=ig_web_copy_link&utm_medium=copy_link&utm_content=share&fbclid=n&img_index=2")
        #expect(result.cleaned == "https://instagram.com/reel/abc/?img_index=2")
        #expect(result.parametersRemoved == 17)
    }

    @Test(arguments: ["/reel/abc/", "/reels/abc/", "/p/abc/", "/tv/abc/", "/stories/user/123/", "/user/", "/share/reel/opaque-token/"])
    func retainsInstagramContentAndSharePaths(path: String) {
        let result = URLCleaner.cleanWithDetails("https://instagram.com\(path)?rpxt=share")
        #expect(result.cleaned == "https://instagram.com\(path)")
        #expect(result.parametersRemoved == 1)
    }

    @Test func preservesUnreviewedNamesOnMirror() {
        let input = "https://kkinstagram.com/reel/abc/?rpxt=keep&obrf=keep&vrfl=keep&cplk=keep&igsi=keep&si=keep&stkn=keep"
        #expect(URLCleaner.clean(input) == input)
    }

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
