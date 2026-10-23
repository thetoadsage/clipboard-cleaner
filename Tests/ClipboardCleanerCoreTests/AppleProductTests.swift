import Testing
@testable import ClipboardCleanerCore

struct AppleProductTests {
    @Test func cleansReportedPolishingClothURL() {
        let base = "https://www.apple.com/shop/product/mlh74am/a/polishing-cloth"
        let input = base + "?fnode=753a3dc5d161e66cc8e682c87902c21261f9b4f2c75dbf053350048970fb196e3210c5e2882765cbe3291b668dfe4499d8c419df46047885ac3889ccd0bd671435001d7c2eec98c972f325d4990e9af95e69eeb181ccab21697dc0b059e0400a"
        let result = URLCleaner.cleanWithDetails(input)
        #expect(result.cleaned == base)
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(result.cleaned).parametersRemoved == 0)
    }

    @Test(arguments: ["www.apple.com", "apple.com", "WWW.APPLE.COM:443"])
    func preservesOtherParametersAndRawEncoding(host: String) {
        let base = "https://\(host)/shop/product/mlh74am/a/polishing-cloth"
        let result = URLCleaner.cleanWithDetails(base + "?color=space+gray&FNODE=one&%66node=two&tag=a&tag=b&fnode_extra=keep#part%23one")
        #expect(result.cleaned == base + "?color=space+gray&tag=a&tag=b&fnode_extra=keep#part%23one")
        #expect(result.parametersRemoved == 2)
    }

    @Test func cleansLocalizedProductLink() {
        #expect(URLCleaner.clean("https://www.apple.com/uk/shop/product/mlh74am/a/polishing-cloth?fnode=nav") == "https://www.apple.com/uk/shop/product/mlh74am/a/polishing-cloth")
    }

    @Test(arguments: [
        "https://www.apple.com/shop/accessories/all?fnode=keep",
        "https://www.apple.com/shop/search?fnode=keep",
        "https://www.apple.com/shop/product/?fnode=keep",
        "https://www.apple.com/shop/productivity/item?fnode=keep",
        "https://www.apple.com/support?fnode=keep",
        "https://www.apple.com.example.com/shop/product/item?fnode=keep",
        "https://notapple.com/shop/product/item?fnode=keep",
        "https://example.com/shop/product/item?fnode=keep",
    ])
    func preservesOutsideProductScope(input: String) {
        #expect(URLCleaner.clean(input) == input)
    }
}
