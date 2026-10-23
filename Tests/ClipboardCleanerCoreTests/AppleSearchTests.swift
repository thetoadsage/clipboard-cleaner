import Testing
@testable import ClipboardCleanerCore

struct AppleSearchTests {
    @Test func cleansReportedSearchURL() {
        let input = "https://www.apple.com/us/search/polishing-cloth?src=globalnav"
        let result = URLCleaner.cleanWithDetails(input)
        #expect(result.cleaned == "https://www.apple.com/us/search/polishing-cloth")
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(result.cleaned).parametersRemoved == 0)
    }

    @Test(arguments: [
        "https://apple.com/search/polishing-cloth",
        "https://www.apple.com/uk/search/polishing-cloth",
        "https://WWW.APPLE.COM:443/us/search/polishing-cloth",
    ])
    func preservesQuerySpellingAndFunctionalValues(base: String) {
        let result = URLCleaner.cleanWithDetails(base + "?q=polishing+cloth&src=globalnav&src=keep&%73rc=global%6Eav&tag=a&tag=b#part%23one")
        #expect(result.cleaned == base + "?q=polishing+cloth&src=keep&tag=a&tag=b#part%23one")
        #expect(result.parametersRemoved == 2)
    }

    @Test(arguments: [
        "https://www.apple.com/us/search/polishing-cloth?src=other",
        "https://www.apple.com/us/search/polishing-cloth?src=globalnavigation",
        "https://www.apple.com/us/search/polishing-cloth?src=",
        "https://www.apple.com/us/search/polishing-cloth?src_extra=globalnav",
        "https://www.apple.com/us/searching/polishing-cloth?src=globalnav",
        "https://www.apple.com/us/shop/product/item?src=globalnav",
        "https://www.apple.com/us/support?src=globalnav",
        "https://www.apple.com.example.com/us/search/polishing-cloth?src=globalnav",
        "https://notapple.com/us/search/polishing-cloth?src=globalnav",
        "https://example.com/us/search/polishing-cloth?src=globalnav",
    ])
    func preservesOutsideReviewedScope(input: String) {
        #expect(URLCleaner.clean(input) == input)
    }
}
