import Foundation

/// Pré-traitement texte PUR (aucune dépendance UI → testable isolément).
/// Port fidèle de `MarkdownPreprocess.kt` (cleanupMath).
///
/// Le modèle émet régulièrement du LaTeX/maths que le rendu markdown maison ne
/// gère pas (`$\text{O}_2$`, `\(a \times b\)`, indices/exposants, notes `[^1]`).
/// `cleanupMath` le convertit en texte lisible (symboles + indices/exposants
/// Unicode) avant le parsing inline.
///
/// Robustesse streaming : un délimiteur non fermé (`$` seul) n'est jamais
/// transformé ; les `$...$` non mathématiques (montants « 5$ ») restent intacts.
func cleanupMath(_ input: String) -> String {
    if input.isEmpty { return input }
    var s = input
    s = replaceAll(MathRE.display, s) { whole, g in looksLikeMath(g[1]) ? renderMath(g[1]) : whole }
    s = replaceAll(MathRE.inline, s) { whole, g in looksLikeMath(g[1]) ? renderMath(g[1]) : whole }
    s = replaceAll(MathRE.paren, s) { _, g in renderMath(g[1]) }
    s = replaceAll(MathRE.brack, s) { _, g in renderMath(g[1]) }
    s = replaceAll(MathRE.footnote, s) { _, _ in "" }
    return s
}

private func looksLikeMath(_ inner: String) -> Bool {
    inner.contains { $0 == "\\" || $0 == "_" || $0 == "^" || $0 == "{" }
}

/// Convertit une expression LaTeX en texte Unicode au mieux.
private func renderMath(_ expr: String) -> String {
    var s = expr
    // \text{...}, \mathrm{...}, etc. → contenu
    s = replaceAll(MathRE.textWrap, s) { _, g in g[1] }
    // Symboles courants (avant le strip générique pour préserver \sqrt, etc.)
    for (k, v) in mathSymbols { s = s.replacingOccurrences(of: k, with: v) }
    // Toute autre commande à argument \cmd{arg} → arg (ex. \vec{v} → v)
    s = replaceAll(MathRE.genericWrap, s) { _, g in g[1] }
    // Indices et exposants (accolades puis caractère seul)
    s = replaceAll(MathRE.subBrace, s) { _, g in toScript(g[1], subscriptMap) }
    s = replaceAll(MathRE.subChar, s) { _, g in toScript(g[1], subscriptMap) }
    s = replaceAll(MathRE.supBrace, s) { _, g in toScript(g[1], superscriptMap) }
    s = replaceAll(MathRE.supChar, s) { _, g in toScript(g[1], superscriptMap) }
    // Espacements LaTeX
    s = s.replacingOccurrences(of: "\\,", with: " ")
        .replacingOccurrences(of: "\\;", with: " ")
        .replacingOccurrences(of: "\\:", with: " ")
        .replacingOccurrences(of: "\\!", with: "")
        .replacingOccurrences(of: "\\\\", with: " ")
        .replacingOccurrences(of: "\\ ", with: " ")
    // Commandes \xxx restantes → nom sans antislash
    s = replaceAll(MathRE.leftoverCmd, s) { _, g in g[1] }
    // Accolades résiduelles
    s = s.replacingOccurrences(of: "{", with: "").replacingOccurrences(of: "}", with: "")
    // Espaces multiples
    s = replaceAll(MathRE.multispace, s) { _, _ in " " }
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func toScript(_ text: String, _ map: [Character: Character]) -> String {
    String(text.map { map[$0] ?? $0 })
}

// MARK: - Regex helpers

private enum MathRE {
    static let display = re(#"\$\$(.+?)\$\$"#, dotAll: true)
    static let inline = re(#"\$([^\$\n]+?)\$"#)
    static let paren = re(#"\\\((.+?)\\\)"#, dotAll: true)
    static let brack = re(#"\\\[(.+?)\\\]"#, dotAll: true)
    static let footnote = re(#"\[\^[^\]]*\]"#)
    static let textWrap = re(#"\\(?:text|mathrm|mathbf|mathit|mathsf|operatorname)\s*\{([^}]*)\}"#)
    static let genericWrap = re(#"\\[A-Za-z]+\s*\{([^}]*)\}"#)
    static let subBrace = re(#"_\{([^}]*)\}"#)
    static let subChar = re(#"_([0-9A-Za-z+\-=()])"#)
    static let supBrace = re(#"\^\{([^}]*)\}"#)
    static let supChar = re(#"\^([0-9A-Za-z+\-=()])"#)
    static let leftoverCmd = re(#"\\([A-Za-z]+)"#)
    static let multispace = re(#" {2,}"#)
}

private func re(_ pattern: String, dotAll: Bool = false) -> NSRegularExpression {
    var opts: NSRegularExpression.Options = []
    if dotAll { opts.insert(.dotMatchesLineSeparators) }
    // swiftlint:disable:next force_try
    return try! NSRegularExpression(pattern: pattern, options: opts)
}

/// Remplace toutes les occurrences ; `transform` reçoit (matchEntier, [groupes]).
/// Les remplacements se font en ordre inverse pour préserver les indices.
private func replaceAll(_ regex: NSRegularExpression, _ s: String,
                        _ transform: (String, [String]) -> String) -> String {
    let ns = s as NSString
    let matches = regex.matches(in: s, range: NSRange(location: 0, length: ns.length))
    if matches.isEmpty { return s }
    let mut = NSMutableString(string: s)
    for m in matches.reversed() {
        var groups: [String] = []
        for i in 0..<m.numberOfRanges {
            let r = m.range(at: i)
            groups.append(r.location == NSNotFound ? "" : ns.substring(with: r))
        }
        mut.replaceCharacters(in: m.range, with: transform(groups[0], groups))
    }
    return mut as String
}

// MARK: - Tables (ordre préservé pour le remplacement des symboles)

private let mathSymbols: [(String, String)] = [
    ("\\times", "×"), ("\\cdot", "·"), ("\\div", "÷"), ("\\pm", "±"), ("\\mp", "∓"),
    ("\\leftrightarrow", "↔"), ("\\rightarrow", "→"), ("\\leftarrow", "←"),
    ("\\Rightarrow", "⇒"), ("\\Leftarrow", "⇐"), ("\\to", "→"),
    ("\\approx", "≈"), ("\\neq", "≠"), ("\\equiv", "≡"),
    ("\\leq", "≤"), ("\\geq", "≥"), ("\\le", "≤"), ("\\ge", "≥"),
    ("\\infty", "∞"), ("\\degree", "°"), ("\\circ", "°"),
    ("\\sum", "∑"), ("\\prod", "∏"), ("\\sqrt", "√"), ("\\int", "∫"),
    ("\\partial", "∂"), ("\\nabla", "∇"), ("\\propto", "∝"),
    ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\delta", "δ"),
    ("\\epsilon", "ε"), ("\\theta", "θ"), ("\\lambda", "λ"), ("\\mu", "µ"),
    ("\\pi", "π"), ("\\rho", "ρ"), ("\\sigma", "σ"), ("\\tau", "τ"),
    ("\\phi", "φ"), ("\\omega", "ω"),
    ("\\Delta", "Δ"), ("\\Sigma", "Σ"), ("\\Omega", "Ω"), ("\\Pi", "Π"),
]

private let superscriptMap: [Character: Character] = [
    "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵",
    "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "+": "⁺", "-": "⁻",
    "=": "⁼", "(": "⁽", ")": "⁾", "n": "ⁿ", "i": "ⁱ",
]

private let subscriptMap: [Character: Character] = [
    "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅",
    "6": "₆", "7": "₇", "8": "₈", "9": "₉", "+": "₊", "-": "₋",
    "=": "₌", "(": "₍", ")": "₎", "a": "ₐ", "e": "ₑ", "o": "ₒ",
    "x": "ₓ", "h": "ₕ", "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ",
    "p": "ₚ", "s": "ₛ", "t": "ₜ",
]
