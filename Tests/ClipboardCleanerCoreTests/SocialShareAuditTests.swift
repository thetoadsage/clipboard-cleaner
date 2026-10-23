import Testing
@testable import ClipboardCleanerCore

struct SocialShareAuditTests {
    @Test(arguments: ["www.youtube.com", "M.YOUTUBE.COM:443", "music.youtube.com"])
    func removesVideoAttributionAndPreservesPlayback(host: String) {
        for path in ["/watch", "/shorts/abc123", "/live/abc123/", "/embed/abc123"] {
            let base = "https://\(host)\(path)"
            let kept = "v=abc123&t=42&start=42&end=90&list=PL123&index=2&origin=https%3A%2F%2Fexample.com&enablejsapi=1&tag=a&tag=b"
            let result = URLCleaner.cleanWithDetails(base + "?embeds_referring_euri=source&\(kept)&embeds_referring_origin=source&source_ve_path=source#part%23one")
            let expected = base + "?" + kept + "#part%23one"
            #expect(result.cleaned == expected)
            #expect(result.parametersRemoved == 3)
            #expect(URLCleaner.cleanWithDetails(expected) == .init(cleaned: expected, parametersRemoved: 0))
        }
    }

    @Test(arguments: ["youtube.com", "WWW.YOUTUBE.COM:443"])
    func removesShortsIsWithOneOptionalTrailingSlash(host: String) {
        for path in ["/shorts/abc123", "/shorts/abc123/"] {
            let base = "https://\(host)\(path)"
            let result = URLCleaner.cleanWithDetails(" \n" + base + "?IS=one&t=42&%69s=two&is#chapter\t")
            #expect(result.cleaned == base + "?t=42#chapter")
            #expect(result.parametersRemoved == 3)
        }
    }

    @Test(arguments: ["twitter.com", "x.com", "mobile.twitter.com", "WWW.X.COM:443"])
    func removesTweetContextAndKeepsLanguageAndMedia(host: String) {
        for path in ["/user/status/123", "/user/status/123/", "/user/status/123/photo/1", "/i/web/status/123", "/i/status/123"] {
            let base = "https://\(host)\(path)"
            let result = URLCleaner.cleanWithDetails(base + "?CXT=one&lang=en&%63xt=two&custom=%2f+%20&tag=a&tag=b#photo")
            #expect(result.cleaned == base + "?lang=en&custom=%2f+%20&tag=a&tag=b#photo")
            #expect(result.parametersRemoved == 2)
        }
    }

    @Test(arguments: ["reddit.com", "www.reddit.com", "old.reddit.com", "SH.REDDIT.COM:443"])
    func removesPostReferralContextAndKeepsCommentSelection(host: String) {
        for path in ["/r/swift/comments/abc123/title/", "/r/swift/comments/abc123/title/def456/", "/comments/abc123", "/user/example/comments/abc123/title/"] {
            let base = "https://\(host)\(path)"
            let kept = "context=3&sort=new&comment=def456&depth=4&limit=20&custom=%2f+%20&tag=a&tag=b"
            let result = URLCleaner.cleanWithDetails(base + "?entry_point=share&target_user=recipient&post_index=1&post_fullname=t3_abc123&_branch_referrer=token&" + kept + "#comment")
            #expect(result.cleaned == base + "?" + kept + "#comment")
            #expect(result.parametersRemoved == 5)
        }
    }

    @Test(arguments: [
        ("https://youtube.com/watch?v=abc123&", "SOURCE_VE_PATH=one&%73ource_ve_path=two&source_ve_path"),
        ("https://x.com/user/status/123?", "CXT=one&%63xt=two&cxt"),
        ("https://reddit.com/r/swift/comments/abc123/?", "ENTRY_POINT=one&%65ntry_point=two&entry_point"),
        ("https://reddit.com/comments/abc123?", "TARGET_USER=one&%74arget_user=two&target_user"),
        ("https://reddit.com/comments/abc123?", "POST_INDEX=one&%70ost_index=two&post_index"),
        ("https://reddit.com/comments/abc123?", "POST_FULLNAME=one&%70ost_fullname=two&post_fullname"),
        ("https://reddit.com/comments/abc123?", "_BRANCH_REFERRER=one&%5fbranch_referrer=two&_branch_referrer"),
    ])
    func matchesEncodedRepeatedAndBareNames(base: String, query: String) {
        let result = URLCleaner.cleanWithDetails(base + query + "&custom=keep")
        #expect(result.cleaned == base + "custom=keep")
        #expect(result.parametersRemoved == 3)
        #expect(URLCleaner.cleanWithDetails(result.cleaned).parametersRemoved == 0)
    }

    @Test(arguments: [
        "https://example.com/watch?v=abc&source_ve_path=keep&cxt=keep&entry_point=keep",
        "https://youtube.com.example.com/watch?v=abc&source_ve_path=keep",
        "https://notyoutube.com/embed/abc?embeds_referring_euri=keep",
        "https://youtube.com/watchlist?source_ve_path=keep",
        "https://youtube.com/shorts/?source_ve_path=keep&is=keep",
        "https://youtube.com/shorts/abc/extra?source_ve_path=keep&is=keep",
        "https://youtube.com/shorts/abc//?is=keep",
        "https://youtube.com/watch?v=abc&is=keep&source_ve_path_extra=keep",
        "https://youtube.com/signin?source_ve_path=keep",
        "https://youtube.com/redirect?q=https%3A%2F%2Fexample.com&source_ve_path=keep",
        "https://youtube.com/@user?source_ve_path=keep",
        "https://x.com.example.com/user/status/123?cxt=keep",
        "https://nottwitter.com/user/status/123?cxt=keep",
        "https://x.com/i/redirect?url=https%3A%2F%2Fexample.com&s=20&t=signature&cxt=keep",
        "https://twitter.com/i/redirect?url=https%3A%2F%2Fexample.com&s=20&t=signature&cxt=keep",
        "https://x.com/search?q=test&cxt=keep",
        "https://x.com/user?cxt=keep",
        "https://x.com/user/status/not-a-post?cxt=keep",
        "https://x.com/user/status/123?cxt_extra=keep",
        "https://reddit.com.example.com/comments/abc?entry_point=keep",
        "https://notreddit.com/comments/abc?target_user=keep",
        "https://reddit.com/search?post_fullname=keep&post_index=keep",
        "https://reddit.com/api/info?post_fullname=keep&target_user=keep",
        "https://reddit.com/r/swift/?entry_point=keep",
        "https://reddit.com/comments/?entry_point=keep",
        "https://reddit.com/r/swift/s/opaque?entry_point=keep",
        "https://reddit.app.link/opaque?utm_content=comment_id&_branch_referrer=keep",
        "https://reddit.com/comments/abc?entry_point_extra=keep&_branch_referrer_extra=keep",
    ])
    func preservesOutsideReviewedScope(input: String) {
        #expect(URLCleaner.cleanWithDetails(input) == .init(cleaned: input, parametersRemoved: 0))
    }
}
