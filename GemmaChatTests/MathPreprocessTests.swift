import XCTest

/// Port des tests JVM purs du pré-traitement LaTeX/maths (MarkdownPreprocessTest.kt).
/// Couvre les cas réels émis par le modèle + robustesse streaming.
final class MathPreprocessTests: XCTestCase {

    func testStripsInlineTextWrapper() {
        XCTAssertEqual(cleanupMath("La molécule $\\text{G3P}$ est clé."), "La molécule G3P est clé.")
    }

    func testSubscriptDigitsToUnicode() {
        XCTAssertEqual(cleanupMath("Formule $\\text{O}_2$ et $\\text{CO}_2$."), "Formule O₂ et CO₂.")
    }

    func testWaterFormula() {
        XCTAssertEqual(cleanupMath("$\\text{H}_2\\text{O}$"), "H₂O")
    }

    func testSuperscriptBraces() {
        XCTAssertEqual(cleanupMath("$x^{2}$ + $y^2$"), "x² + y²")
    }

    func testIonCharge() {
        XCTAssertEqual(cleanupMath("$\\text{Ca}^{2+}$"), "Ca²⁺")
    }

    func testParenDelimiterAndTimes() {
        XCTAssertEqual(cleanupMath("\\(a \\times b\\)"), "a × b")
    }

    func testBracketDisplayDelimiter() {
        XCTAssertEqual(cleanupMath("\\[E = mc^2\\]"), "E = mc²")
    }

    func testGreekAndArrow() {
        XCTAssertEqual(cleanupMath("$\\alpha \\to \\beta$"), "α → β")
    }

    func testRemovesFootnoteRefs() {
        XCTAssertEqual(cleanupMath("Un fait important[^1]."), "Un fait important.")
    }

    func testKeepsCurrencyDollars() {
        XCTAssertEqual(cleanupMath("entre 5$ et 10$"), "entre 5$ et 10$")
    }

    func testStreamingUnclosedDollarIsLiteral() {
        XCTAssertEqual(cleanupMath("calcul de $\\text{O"), "calcul de $\\text{O")
    }

    func testPlainTextUnchanged() {
        XCTAssertEqual(cleanupMath("Bonjour, comment ça va ?"), "Bonjour, comment ça va ?")
    }

    func testEmptyStays() {
        XCTAssertEqual(cleanupMath(""), "")
    }

    func testGenericCommandKeepsArgument() {
        XCTAssertEqual(cleanupMath("$\\vec{v}$"), "v")
    }

    func testSqrtSymbolPreserved() {
        XCTAssertEqual(cleanupMath("$\\sqrt{2}$"), "√2")
    }
}
