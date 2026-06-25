import SwiftUI
import AppKit

/// Rendu Markdown maison (équivalent MarkdownText.kt) : blocs de code avec bouton
/// copier, inline gras/italique/code, titres, listes. Robuste au streaming
/// (marqueurs non fermés laissés littéraux). Pré-traitement maths via cleanupMath.
struct MarkdownView: View {
    let text: String

    var body: some View {
        let blocks = MarkdownParser.parse(cleanupMath(text))
        VStack(alignment: .leading, spacing: 8) {
            ForEach(blocks.indices, id: \.self) { i in
                switch blocks[i] {
                case .code(let language, let code):
                    CodeBlockView(language: language, code: code)
                case .text(let content):
                    TextBlockView(content: content)
                }
            }
        }
    }
}

// MARK: - Parsing en blocs

enum MarkdownBlock {
    case text(String)
    case code(language: String?, code: String)
}

enum MarkdownParser {
    /// Découpe en blocs texte / code. Une fence ``` non fermée (streaming) est
    /// rendue comme texte, jamais comme bloc de code.
    static func parse(_ input: String) -> [MarkdownBlock] {
        let lines = input.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var textBuffer: [String] = []
        var codeBuffer: [String] = []
        var inCode = false
        var codeLang: String?

        func flushText() {
            let joined = textBuffer.joined(separator: "\n")
            if !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.text(joined))
            }
            textBuffer.removeAll()
        }

        for line in lines {
            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(language: codeLang, code: codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll()
                    inCode = false
                    codeLang = nil
                } else {
                    flushText()
                    inCode = true
                    let lang = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeLang = lang.isEmpty ? nil : lang
                }
            } else if inCode {
                codeBuffer.append(line)
            } else {
                textBuffer.append(line)
            }
        }
        // Fence non fermée → on rend le contenu accumulé comme texte (streaming-safe).
        if inCode {
            if codeLang != nil { textBuffer.append("```\(codeLang!)") } else { textBuffer.append("```") }
            textBuffer.append(contentsOf: codeBuffer)
        }
        flushText()
        return blocks
    }
}

// MARK: - Bloc texte (titres, listes, paragraphes)

private struct TextBlockView: View {
    let content: String

    var body: some View {
        let lines = content.components(separatedBy: "\n")
        VStack(alignment: .leading, spacing: 3) {
            ForEach(lines.indices, id: \.self) { i in
                lineView(lines[i])
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            Spacer().frame(height: 2)
        } else if let (level, rest) = heading(trimmed) {
            Text(InlineMarkdown.attributed(rest))
                .font(GemmaFont.manrope(headingSize(level), weight: .bold))
                .foregroundColor(GemmaColors.textPrimary)
                .padding(.top, 2)
        } else if let bullet = bulletItem(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundColor(GemmaColors.accentPurple)
                Text(InlineMarkdown.attributed(bullet))
                    .font(.gemmaBodyLarge).foregroundColor(GemmaColors.textSecondary)
            }
        } else if let (marker, rest) = numberedItem(trimmed) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker).foregroundColor(GemmaColors.accentPurple)
                    .font(.gemmaBodyLarge)
                Text(InlineMarkdown.attributed(rest))
                    .font(.gemmaBodyLarge).foregroundColor(GemmaColors.textSecondary)
            }
        } else {
            Text(InlineMarkdown.attributed(line))
                .font(.gemmaBodyLarge)
                .foregroundColor(GemmaColors.textSecondary)
                .textSelection(.enabled)
        }
    }

    private func heading(_ s: String) -> (Int, String)? {
        var level = 0
        for c in s { if c == "#" { level += 1 } else { break } }
        guard (1...6).contains(level), s.count > level,
              s[s.index(s.startIndex, offsetBy: level)] == " " else { return nil }
        let rest = String(s.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        return (level, rest)
    }

    private func headingSize(_ level: Int) -> CGFloat {
        switch level { case 1: return 19; case 2: return 17; default: return 15.5 }
    }

    private func bulletItem(_ s: String) -> String? {
        if s.hasPrefix("- ") || s.hasPrefix("* ") { return String(s.dropFirst(2)) }
        return nil
    }

    private func numberedItem(_ s: String) -> (String, String)? {
        // "1. texte" → ("1.", "texte")
        guard let dotIdx = s.firstIndex(of: ".") else { return nil }
        let numPart = s[s.startIndex..<dotIdx]
        guard !numPart.isEmpty, numPart.allSatisfy({ $0.isNumber }),
              s.index(after: dotIdx) < s.endIndex,
              s[s.index(after: dotIdx)] == " " else { return nil }
        let rest = String(s[s.index(dotIdx, offsetBy: 2)...])
        return ("\(numPart).", rest)
    }
}

// MARK: - Bloc de code

private struct CodeBlockView: View {
    let language: String?
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language ?? "code")
                    .font(GemmaFont.mono(11, weight: .medium))
                    .foregroundColor(GemmaColors.textMuted)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                } label: {
                    Text(copied ? "Copié" : "Copier")
                        .font(.gemmaLabelMedium)
                        .foregroundColor(copied ? GemmaColors.success : GemmaColors.textIcon)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(GemmaColors.surfacePill)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(GemmaFont.mono(13))
                    .foregroundColor(GemmaColors.textPrimary)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(GemmaColors.surfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(GemmaColors.borderSubtle, lineWidth: 1))
    }
}

// MARK: - Inline (gras / italique / code)

enum InlineMarkdown {
    static func attributed(_ s: String) -> AttributedString {
        var out = AttributedString()
        for segment in tokenize(s) {
            var run = AttributedString(segment.text)
            switch segment.style {
            case .normal:
                run.font = .gemmaBodyLarge
            case .bold:
                run.font = GemmaFont.manrope(15, weight: .bold)
            case .italic:
                run.font = .gemmaBodyLarge.italic()
            case .code:
                run.font = GemmaFont.mono(13)
                run.foregroundColor = GemmaColors.accentPurplePale
                run.backgroundColor = GemmaColors.surfaceInput
            }
            out.append(run)
        }
        return out
    }

    private enum Style { case normal, bold, italic, code }
    private struct Segment { let text: String; let style: Style }

    private static func tokenize(_ s: String) -> [Segment] {
        let chars = Array(s)
        var result: [Segment] = []
        var buffer = ""
        var i = 0
        func flush() { if !buffer.isEmpty { result.append(Segment(text: buffer, style: .normal)); buffer = "" } }

        while i < chars.count {
            let c = chars[i]
            if c == "`", let close = indexOf(chars, "`", from: i + 1) {
                flush()
                append(&result, String(chars[(i + 1)..<close]), .code)
                i = close + 1
            } else if c == "*", i + 1 < chars.count, chars[i + 1] == "*",
                      let close = indexOfDouble(chars, from: i + 2) {
                flush()
                append(&result, String(chars[(i + 2)..<close]), .bold)
                i = close + 2
            } else if c == "*", i + 1 < chars.count,
                      chars[i + 1] != "*", !chars[i + 1].isWhitespace,
                      let close = indexOfSingleStar(chars, from: i + 1) {
                // Italique seulement si l'ouvrant n'est pas un `**` (non fermé → littéral)
                // ni suivi d'une espace (évite « a * b * c » faux-italique).
                flush()
                append(&result, String(chars[(i + 1)..<close]), .italic)
                i = close + 1
            } else {
                buffer.append(c)
                i += 1
            }
        }
        flush()
        return result
    }

    private static func append(_ result: inout [Segment], _ text: String, _ style: Style) {
        if !text.isEmpty { result.append(Segment(text: text, style: style)) }
    }

    private static func indexOf(_ chars: [Character], _ target: Character, from: Int) -> Int? {
        var i = from
        while i < chars.count { if chars[i] == target { return i }; i += 1 }
        return nil
    }

    private static func indexOfDouble(_ chars: [Character], from: Int) -> Int? {
        var i = from
        while i + 1 < chars.count { if chars[i] == "*" && chars[i + 1] == "*" { return i }; i += 1 }
        return nil
    }

    private static func indexOfSingleStar(_ chars: [Character], from: Int) -> Int? {
        var i = from
        while i < chars.count {
            if chars[i] == "*" && (i + 1 >= chars.count || chars[i + 1] != "*") { return i }
            i += 1
        }
        return nil
    }
}
