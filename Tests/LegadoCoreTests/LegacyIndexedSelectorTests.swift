import XCTest
@testable import LegadoCore

/// 老式 `class.x.N@tag.y.N` 选择器的下标回归测试。
///
/// 这类写法在真实书源里非常常见（例如 `class.bookname.0@tag.a.0@text`），
/// `normalizeSelector` 把它变成 `.bookname.0` / `a.0` 之后，如果只认「标签.下标」，
/// 带下标的 class 规则就会整条取不到元素。
final class LegacyIndexedSelectorTests: XCTestCase {

    private let html = """
    <html><body>
        <div class="bookname"><a href="/book/1">第一本</a></div>
        <div class="bookname"><a href="/book/2">第二本</a></div>
        <div class="bookname"><a href="/book/3">第三本</a></div>
        <ul class="chapters">
            <li><a href="/c/1">第一章</a></li>
            <li><a href="/c/2">第二章</a></li>
        </ul>
    </body></html>
    """

    func testSplitIndexSuffix() {
        let a = RuleAnalyzer.splitIndexSuffix("a.0")
        XCTAssertEqual(a?.base, "a")
        XCTAssertEqual(a?.index, 0)

        let b = RuleAnalyzer.splitIndexSuffix(".bookname.0")
        XCTAssertEqual(b?.base, ".bookname")
        XCTAssertEqual(b?.index, 0)

        let c = RuleAnalyzer.splitIndexSuffix("#list.-1")
        XCTAssertEqual(c?.base, "#list")
        XCTAssertEqual(c?.index, -1)

        // 类名里的数字不能被当成下标
        XCTAssertNil(RuleAnalyzer.splitIndexSuffix("div.mt-2"))
        XCTAssertNil(RuleAnalyzer.splitIndexSuffix(".col-3"))
        XCTAssertNil(RuleAnalyzer.splitIndexSuffix("div.bookname"))
    }

    func testTokenizerKeepsLegacyIndexes() {
        let steps = RuleTokenizer.parse("class.bookname.0@tag.a.0@href")
        XCTAssertEqual(steps.map(\.type), [
            .css(".bookname.0"),
            .css("a.0"),
            .attribute("href"),
        ])
    }

    func testIndexedClassRuleSelectsSingleElement() {
        let analyzer = RuleAnalyzer(content: html, baseUrl: "https://example.com")
        XCTAssertEqual(analyzer.getString("class.bookname.0@tag.a.0@text"), "第一本")
        XCTAssertEqual(analyzer.getString("class.bookname.1@tag.a.0@text"), "第二本")
        XCTAssertEqual(analyzer.getString("class.bookname.-1@tag.a.0@text"), "第三本")
        XCTAssertEqual(analyzer.getString("class.bookname.5@tag.a.0@text"), "")
        XCTAssertEqual(analyzer.getString("class.bookname.0@tag.a.0@href", isUrl: true),
                       "https://example.com/book/1")
    }

    func testNonIndexedClassRuleStillReturnsAll() {
        let analyzer = RuleAnalyzer(content: html, baseUrl: "https://example.com")
        XCTAssertEqual(analyzer.getStringList("class.bookname@tag.a@text"), ["第一本", "第二本", "第三本"])
        XCTAssertEqual(analyzer.getStringList("ul.chapters@tag.li@tag.a@text"), ["第一章", "第二章"])
    }

    func testIndexedElementListRule() {
        let analyzer = RuleAnalyzer(content: html, baseUrl: "https://example.com")
        let elements = analyzer.getElements("class.bookname")
        XCTAssertEqual(elements.count, 3)
        let first = RuleAnalyzer(content: elements[0])
        XCTAssertEqual(first.getString("tag.a.0@text"), "第一本")
    }
}
