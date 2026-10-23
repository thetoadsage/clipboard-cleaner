import Testing
@testable import ClipboardCleanerCore

struct AppleAttributionTests {
    @Test func cleansSearchSourceAndKeepsFilters() {
        let base = "https://www.apple.com/us/search/polishing-cloth"
        let result = URLCleaner.cleanWithDetails(base + "?src=aos&tab=explore&f=polishingcloth&fh=4ce0f3&sel=accessories")
        #expect(result.cleaned == base + "?tab=explore&f=polishingcloth&fh=4ce0f3&sel=accessories")
        #expect(result.parametersRemoved == 1)
    }

    @Test(arguments: [
        "https://www.apple.com/shop/buy-iphone",
        "https://apple.com/uk/shop/buy-iphone",
        "https://WWW.APPLE.COM:443/today/event/spotlight-apple-intelligence",
        "https://support.apple.com/",
    ])
    func cleansCampaignIdentifiers(base: String) {
        let result = URLCleaner.cleanWithDetails(base + "?cid=rem-us-taa-shop-iphone&lang=en&tag=a&tag=b#details%23one")
        #expect(result.cleaned == base + "?lang=en&tag=a&tag=b#details%23one")
        #expect(result.parametersRemoved == 1)
        #expect(URLCleaner.cleanWithDetails(result.cleaned).parametersRemoved == 0)
    }

    @Test(arguments: ["aos-us-kwgo-iphone", "rem-us-taa-shop-iphone", "gn-ols-home-hp-tab"])
    func checksEachRepeatedCampaignValue(value: String) {
        let base = "https://www.apple.com/shop/buy-iphone"
        let result = URLCleaner.cleanWithDetails(base + "?cid=customer&%63id=\(value)&cid=aos-&cid_extra=keep&src=aos")
        #expect(result.cleaned == base + "?cid=customer&cid=aos-&cid_extra=keep&src=aos")
        #expect(result.parametersRemoved == 1)
    }

    @Test(arguments: ["music", "tv", "podcasts", "books", "apps", "itunes", "geo.music"])
    func cleansServiceAttributionAndKeepsContentSelection(service: String) {
        let base = "https://\(service).apple.com/us/item/123"
        let result = URLCleaner.cleanWithDetails(base + "?itscg=10000&itsct=campaign&at=affiliate&ct=newsletter&i=456&l=en-US&app=messages&mt=8&ls=1")
        #expect(result.cleaned == base + "?i=456&l=en-US&app=messages&mt=8&ls=1")
        #expect(result.parametersRemoved == 4)
    }

    @Test(arguments: ["apps.apple.com", "ITUNES.APPLE.COM:443"])
    func cleansProviderTokensAndEncodedRepeatedNames(host: String) {
        let base = "https://\(host)/app/example/id123"
        let result = URLCleaner.cleanWithDetails(base + "?PT=123&%70t=456&%63t=newsletter&platform=iphone&see-all=reviews&q=a%2Fb+%20c#part%23one")
        #expect(result.cleaned == base + "?platform=iphone&see-all=reviews&q=a%2Fb+%20c#part%23one")
        #expect(result.parametersRemoved == 3)
    }

    @Test(arguments: ["messages", "music", "unknown"])
    func preservesAppleAppSelection(value: String) {
        let input = "https://apps.apple.com/us/app/example/id123?app=\(value)"
        #expect(URLCleaner.clean(input) == input)
    }

    @Test(arguments: [
        "https://example.com/shop/item?cid=aos-us-test&itscg=1&itsct=x&at=x&ct=x&pt=x&app=messages",
        "https://www.apple.com.example.com/shop/item?cid=aos-us-test",
        "https://notapple.com/shop/item?cid=aos-us-test",
        "https://apps.apple.com.example.com/app/id123?at=x&ct=x&pt=x&itscg=1&itsct=x",
        "https://www.apple.com/shop/item?cid=unknown&afid=keep&fs=keep",
        "https://www.apple.com/shop/item?at=keep&ct=keep&pt=keep&itscg=keep&itsct=keep",
        "https://www.apple.com/account?cid=aos-us-test",
        "https://www.apple.com/shopping?cid=aos-us-test",
        "https://music.apple.com/subscribe?pt=keep&src=aos",
        "https://developer.apple.com/documentation?at=keep&ct=keep&pt=keep&cid=aos-us-test",
        "https://www.apple.com/us/search/cloth?src=aos-extra&cid=keep",
    ])
    func preservesOutsideReviewedScope(input: String) {
        #expect(URLCleaner.clean(input) == input)
    }
}
