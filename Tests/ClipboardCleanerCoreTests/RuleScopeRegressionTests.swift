import Testing
@testable import ClipboardCleanerCore

struct RuleScopeRegressionTests {
    @Test(arguments: [
        "https://example.co.uk/page?source=required&search_type=custom",
        "https://example.co.in/page?source=required",
        "https://example.com.au/page?source=required",
        "https://example.co.th/page?from=required&publish_id=123",
        "https://example.com.my/page?from=required&pos=2",
        "https://www.airbnb.com.example.com/page?source=required",
        "https://notairbnb.com/page?source=required",
        "https://twitterXcom/page?ref_src=required",
        "https://index.html/?test=required",
        "https://www.linkedin.com/profile?u=123",
        "https://www.linkedin.com/learning-other?u=123",
        "https://www.linkedin.com/?next=/learning&u=123",
        "https://test.clearurls.xyz/other?test=required",
        "https://www.amazon.com/s?keywords=swift+book",
        "https://www.amazon.com:443/s?keywords=swift+book",
        "https://user:pass@www.amazon.com/s?keywords=swift+book",
        "https://newsletter.lidl.de.example123.com/?x=required",
        "https://www.lidl.de/?x=required",
        "https://www.marketscreener.com/search/?mots=apple&add_mots=pear",
        "https://accounts.google.com/o/oauth2/auth?client_id=demo&source=required&utm_source=required",
        "https://docs.google.com/document/d/123?source=required",
        "https://youtube.com/signin?si=required&feature=required",
        "https://github.com/owner/repo?fbclid=required",
    ])
    func preservesParametersOutsideProviderScope(input: String) {
        #expect(URLCleaner.clean(input) == input)
    }

    @Test(arguments: [
        ("https://www.airbnb.com/rooms/123?federated_search_id=share&id=123", "https://www.airbnb.com/rooms/123?id=123"),
        ("https://www.airbnb.co.uk/rooms/123?source=share", "https://www.airbnb.co.uk/rooms/123"),
        ("https://shopee.co.th/item?publish_id=share", "https://shopee.co.th/item"),
        ("https://lazada.sg/item?from=share", "https://lazada.sg/item"),
        ("https://www.mercadolibre.com/item?tracking_id=share", "https://www.mercadolibre.com/item"),
        ("https://www.mercadolivre.com/item?tracking_id=share", "https://www.mercadolivre.com/item"),
        ("https://www.nikkei.com/article/123?i_cid=share", "https://www.nikkei.com/article/123"),
        ("https://www.nikkei.co.jp/article/123?i_cid=share", "https://www.nikkei.co.jp/article/123"),
        ("https://ya.ru/?text=hello&lr=123", "https://ya.ru/?text=hello"),
        ("https://weibo.cn/post?weibo_id=share", "https://weibo.cn/post"),
        ("https://weibo.com/post?weibo_id=share", "https://weibo.com/post"),
        ("https://www.linkedin.com/learning/course?u=123", "https://www.linkedin.com/learning/course"),
        ("https://newsletter.lidl.de/?x=share&id=1", "https://newsletter.lidl.de/?id=1"),
        ("https://www.amazon.com/s?keywords=swift+book&qid=share&utm_source=share#results", "https://www.amazon.com/s?keywords=swift+book#results"),
        ("https://www.marketscreener.com/search/?mots=apple&noredirect=share", "https://www.marketscreener.com/search/?mots=apple"),
    ])
    func cleansOnlyApplicableProviderParameters(input: String, expected: String) {
        #expect(URLCleaner.clean(input) == expected)
    }
}
