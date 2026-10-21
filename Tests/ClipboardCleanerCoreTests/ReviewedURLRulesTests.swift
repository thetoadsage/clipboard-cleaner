import Foundation
import Testing
@testable import ClipboardCleanerCore

struct ReviewedURLRulesTests {
    @Test(arguments: ["gad_source", "gad_campaignid", "ttclid", "pjclid", "tgclid", "cjevent", "hsa_acc", "hsa_cam", "bsft_uid"])
    func removesReviewedGlobalIdentifiers(name: String) {
        let result = URLCleaner.cleanWithDetails("https://example.com/article?id=42&\(name)=tracking#section")
        #expect(result.cleaned == "https://example.com/article?id=42#section")
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(result.cleaned).parametersRemoved == 0)
    }

    @Test(arguments: [
        ("https://www.facebook.com/share/p/123/?rdid=x&share_url=y&id=42", "https://www.facebook.com/share/p/123/?id=42"),
        ("https://www.instagram.com/p/ABC/?ig_rid=x&id=42", "https://www.instagram.com/p/ABC/?id=42"),
        ("https://www.reddit.com/r/swift/comments/abc/?ref=share&%24web_only=true&id=42", "https://www.reddit.com/r/swift/comments/abc/?id=42"),
        ("https://open.spotify.com/track/abc?pi=x&dlsi=y&t=42", "https://open.spotify.com/track/abc?t=42"),
        ("https://www.tiktok.com/@example/video/123?share_region=US&id=42", "https://www.tiktok.com/@example/video/123?id=42"),
        ("https://youtu.be/abc123?is=x&t=42", "https://youtu.be/abc123?t=42"),
        ("https://www.youtube.com/live/abc123?is=x&t=42", "https://www.youtube.com/live/abc123?t=42"),
    ])
    func cleansReviewedSites(input: String, expected: String) {
        #expect(URLCleaner.clean(input) == expected)
    }

    @Test(arguments: [
        "https://example.com/?rdid=x&share_url=y&ig_rid=z&ref=keep&$web_only=true&pi=a&dlsi=b&share_region=US&is=keep",
        "https://facebook.com.example.com/?rdid=x&share_url=y",
        "https://notinstagram.com/?ig_rid=x",
        "https://spotify.com/track/abc?pi=x&dlsi=y",
        "https://youtube.com/watch?v=abc123&is=keep",
        "https://youtube.com/live/?is=keep",
        "https://youtube.com/live/abc/other?is=keep",
        "https://youtube.com.example.com/live/abc?is=keep",
    ])
    func preservesNamesOutsideReviewedScope(input: String) {
        #expect(URLCleaner.clean(input) == input)
    }

    @Test(arguments: [
        "https://app.plex.tv/auth-form/?utm_source=plex&utm_content=login&utm_medium=web&clientID=keep",
        "https://app.plex.tv:443/auth-form/?utm_source=plex&utm_content=login&utm_medium=web",
        "https://user:pass@app.plex.tv/auth-form/?utm_source=plex",
        "https://reddit.app.link/example?utm_content=reply&id=42",
        "https://greenbuildingadvisor.com/login?oly_enc_id=required",
        "https://www.greenbuildingadvisor.com/login?oly_enc_id=required",
        "https://rd.bizrate.com/rd?utm_campaign=required&utm_medium=required",
        "https://metabase.com/?utm_term=required",
        "https://accounts.google.com/o/oauth2/auth?client_id=keep&gad_source=1&__s=abcdef",
        "https://github.com/owner/repo?gad_source=required",
        "https://urldefense.com/v3/__https://example.com/?utm_source=required&fbclid=required&gad_source=required",
        "https://tix.axs.com/?utm_source=required&gad_source=required",
    ])
    func preservesReviewedFunctionalParameters(input: String) {
        #expect(URLCleaner.clean(input) == input)
    }

    @Test(arguments: [
        ("https://app.plex.tv/auth-form/?utm_source=keep&fbclid=remove&id=42", "https://app.plex.tv/auth-form/?utm_source=keep&id=42"),
        ("https://app.plex.tv/auth-form-other?utm_source=remove", "https://app.plex.tv/auth-form-other"),
        ("https://app.plex.tv.example.com/auth-form/?utm_source=remove", "https://app.plex.tv.example.com/auth-form/"),
        ("https://example.com/?utm_content=remove&oly_enc_id=remove", "https://example.com/"),
        ("https://reddit.app.link/?utm_content=keep&utm_source=remove", "https://reddit.app.link/?utm_content=keep"),
    ])
    func exceptionsProtectOnlyTheirParameterAndScope(input: String, expected: String) {
        #expect(URLCleaner.clean(input) == expected)
    }

    @Test(arguments: ["1", "abcde", "", "abc-123", "日本語", "abcdef!", "abcdef%26keep%3D1", "abcdef%0A"])
    func preservesNonTrackingDripValues(value: String) {
        let input = "https://example.com/search?__s=\(value)&q=keep"
        #expect(URLCleaner.clean(input) == input)
    }

    @Test(arguments: ["abcdef", "Ab1234", "1234567890"])
    func removesTrackingDripValues(value: String) {
        #expect(URLCleaner.clean("https://example.com/search?__s=\(value)&q=keep") == "https://example.com/search?q=keep")
    }

    @Test func evaluatesRepeatedNamesByEachValue() {
        let result = URLCleaner.cleanWithDetails("https://example.com/?__s=1&__s=abcdef&__s=abcd-ef&id=42")
        #expect(result.cleaned == "https://example.com/?__s=1&__s=abcd-ef&id=42")
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.clean("https://univis.uni-kiel.de.example.com/?__s=abcdef") == "https://univis.uni-kiel.de.example.com/")
    }

    @Test(arguments: ["univis.uni-erlangen.de", "univis.uni-bamberg.de", "univis.uni-luebeck.de", "univis.uni-kiel.de", "univis.th-koeln.de"])
    func preservesDripNameOnExcludedHosts(host: String) {
        let input = "https://\(host)/?__s=abcdef"
        #expect(URLCleaner.clean(input) == input)
    }

    private static func wrap(_ prefix: String, destination: String) -> String {
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!
        return prefix + encoded
    }

    @Test(arguments: [
        "https://duckduckgo.com/l/?uddg=",
        "https://www.linkedin.com/redir/redirect?url=",
        "https://l.threads.net/?u=",
        "https://l.threads.com/?u=",
        "https://l.instagram.com/?u=",
        "https://go.skimresources.com/?url=",
        "https://go.redirectingat.com/?url=",
        "https://click.linksynergy.com/deeplink?murl=",
    ])
    func unwrapsReviewedQueryDestinations(prefix: String) {
        let input = Self.wrap(prefix, destination: "https://example.com/article?id=42&utm_source=email#section")
        let result = URLCleaner.cleanWithDetails(input)
        #expect(result.cleaned == "https://example.com/article?id=42#section")
        #expect(result.parametersRemoved == 2)
        #expect(URLCleaner.clean(result.cleaned) == result.cleaned)
    }

    @Test func preservesDestinationEncodingAndNestedWrapperOrder() {
        let destination = "https://example.com/?token=a%26b%3Dc&plus=a%2Bb#frag%23ment"
        let inner = Self.wrap("https://l.instagram.com/?u=", destination: destination)
        let input = Self.wrap("https://duckduckgo.com/l/?uddg=", destination: inner)
        #expect(URLCleaner.clean(input) == destination)
    }

    @Test(arguments: [
        "https://duckduckgo.com/later?uddg=https%3A%2F%2Fexample.com",
        "https://duckduckgo.com.example.com/l/?uddg=https%3A%2F%2Fexample.com",
        "https://www.linkedin.com/redir/redirect-other?url=https%3A%2F%2Fexample.com",
        "https://example.com/?url=https%3A%2F%2Fdestination.example",
        "https://l.instagram.com/other?u=https%3A%2F%2Fexample.com",
        "https://l.instagram.com/?u=javascript%3Aalert(1)",
        "https://l.instagram.com/?u=file%3A%2F%2F%2Ftmp%2Fexample",
        "https://l.instagram.com/?u=https%253A%252F%252Fexample.com",
        "https://l.instagram.com/?u=https%3A%2F%2Fexample.com&u=https%3A%2F%2Fother.example",
        "ftp://duckduckgo.com/l/?uddg=https%3A%2F%2Fexample.com",
    ])
    func leavesUnrecognizedOrAmbiguousWrappers(input: String) {
        #expect(RedirectUnwrapper.fullyUnwrap(input).result == input)
    }

    @Test func decodesBingAndRedditmailDestinationsOffline() {
        let destination = "https://example.com/article?id=42&utm_source=email#section"
        let base64 = Data(destination.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        let bing = "https://www.bing.com/ck/a?u=a1\(base64)&ntb=1"
        let reddit = Self.wrap("https://click.redditmail.com/CL0/", destination: destination) + "/1/01234567-abcd/"
        #expect(URLCleaner.clean(bing) == "https://example.com/article?id=42#section")
        #expect(URLCleaner.clean(reddit) == "https://example.com/article?id=42#section")
        #expect(URLCleaner.cleanWithDetails(bing).parametersRemoved == 3)
        #expect(URLCleaner.cleanWithDetails(reddit).parametersRemoved == 1)
    }

    @Test(arguments: [
        "https://www.bing.com/ck/a?u=a1%%%%",
        "https://www.bing.com/ck/a?u=a1ZmlsZTovLy90bXAvZXhhbXBsZQ",
        "https://www.bing.com/ck/another?u=a1aHR0cHM6Ly9leGFtcGxlLmNvbQ",
        "https://bing.com.example.com/ck/a?u=a1aHR0cHM6Ly9leGFtcGxlLmNvbQ",
        "https://click.redditmail.com/other/https%3A%2F%2Fexample.com/1/abcd/",
        "https://click.redditmail.com/CL0/https%3A%2F%2Fexample.com/nope/abcd/",
        "https://click.redditmail.com.example.com/CL0/https%3A%2F%2Fexample.com/1/abcd/",
    ])
    func preservesMalformedEncodedWrappers(input: String) {
        #expect(RedirectUnwrapper.fullyUnwrap(input).result == input)
    }
}
