import Testing
@testable import ClipboardCleanerCore

struct GitHubUTMTests {
    @Test func cleansReportedHearthURL() {
        let result = URLCleaner.cleanWithDetails("https://github.com/helv-io/hearth?utm_source=chatgpt.com")
        #expect(result.cleaned == "https://github.com/helv-io/hearth")
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(result.cleaned).parametersRemoved == 0)
    }

    @Test(arguments: ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id"])
    func removesCampaignParameters(name: String) {
        let result = URLCleaner.cleanWithDetails("https://github.com/owner/repo?\(name)=share")
        #expect(result.cleaned == "https://github.com/owner/repo")
        #expect(result.parametersRemoved == 1)
    }

    @Test(arguments: ["github.com", "www.github.com", "gist.github.com", "GITHUB.COM:443"])
    func preservesFunctionalParametersAndRawSpelling(host: String) {
        let result = URLCleaner.cleanWithDetails("https://\(host)/owner/repo?q=label%3Abug+is%3Aopen&UTM_SOURCE=share&tab=readme-ov-file&ref=main&gad_source=keep&tag=a&tag=b&%75tm_source=again#readme%23part")
        #expect(result.cleaned == "https://\(host)/owner/repo?q=label%3Abug+is%3Aopen&tab=readme-ov-file&ref=main&gad_source=keep&tag=a&tag=b#readme%23part")
        #expect(result.parametersRemoved == 2)
    }

    @Test func keepsUnreviewedGitHubParameters() {
        let input = "https://github.com/owner/repo?utm_custom=keep&utm_source_extra=keep&fbclid=keep&gad_source=keep&ref=main&tab=readme-ov-file"
        #expect(URLCleaner.clean(input) == input)
    }

    @Test(arguments: ["github.com.example.com", "notgithub.com", "githubXcom", "gitlab.com", "accounts.google.com"])
    func scopesLocalOverrideToGitHub(host: String) {
        let rules = TrackingRuleCatalog.shared.rules(for: host, url: "https://\(host)/owner/repo?utm_source=share")
        // Other hosts may have their own UTM rules; inspect the local domain
        // additions rather than confusing those with this GitHub override.
        #expect(!rules.literal.contains("utm_source"))
    }

    @Test(arguments: [
        "https://gitlab.com/owner/repo?utm_source=keep",
        "https://accounts.google.com/o/oauth2/auth?utm_source=keep&client_id=keep",
        "https://app.plex.tv/auth-form/?utm_source=keep&clientID=keep",
    ])
    func preservesOtherSitesExceptions(input: String) {
        #expect(URLCleaner.clean(input) == input)
    }
}
