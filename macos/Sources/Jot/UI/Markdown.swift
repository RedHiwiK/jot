import SwiftUI

/// Lightweight Markdown rendering.
///
/// Not SwiftUI's built-in AttributedString(markdown:): it doesn't support headings or lists,
/// and requirement bodies are all ## and - [ ], so it would be useless.
///
/// Typography modeled on Typora: comfortable paragraph spacing (0.6em), restrained heading sizes (no large type),
/// shaded code blocks, blockquotes with a left rule.

enum MDBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(text: String, checked: Bool?)   // checked != nil means a task list item
    case ordered(index: Int, text: String)
    case code(lang: String?, body: String)
    case quote(String)
    case divider
    case blank

    var id: String { UUID().uuidString }
}

enum MDParser {
    static func parse(_ src: String) -> [MDBlock] {
        var blocks: [MDBlock] = []
        let lines = src.components(separatedBy: .newlines)
        var i = 0
        var paraBuf: [String] = []

        func flushPara() {
            let t = paraBuf.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { blocks.append(.paragraph(t)) }
            paraBuf = []
        }

        while i < lines.count {
            let raw = lines[i]
            let line = raw.trimmingCharacters(in: .whitespaces)

            // Code block
            if line.hasPrefix("```") {
                flushPara()
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var body: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    body.append(lines[i]); i += 1
                }
                i += 1
                blocks.append(.code(lang: lang.isEmpty ? nil : lang,
                                    body: body.joined(separator: "\n")))
                continue
            }

            // Heading
            if let m = line.firstMatch(of: /^(#{1,6})\s+(.*)$/) {
                flushPara()
                blocks.append(.heading(level: m.1.count, text: String(m.2)))
                i += 1; continue
            }

            // Horizontal rule
            if line == "---" || line == "***" || line == "___" {
                flushPara()
                blocks.append(.divider)
                i += 1; continue
            }

            // Task item / unordered list
            if let m = line.firstMatch(of: /^[-*+]\s+\[([ xX])\]\s*(.*)$/) {
                flushPara()
                // An empty checkbox is a template placeholder; don't render it
                let text = String(m.2).trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    blocks.append(.bullet(text: text, checked: m.1.lowercased() == "x"))
                }
                i += 1; continue
            }
            if let m = line.firstMatch(of: /^[-*+]\s+(.*)$/) {
                flushPara()
                blocks.append(.bullet(text: String(m.1), checked: nil))
                i += 1; continue
            }

            // Ordered list
            if let m = line.firstMatch(of: /^(\d+)[.)]\s+(.*)$/) {
                flushPara()
                blocks.append(.ordered(index: Int(m.1) ?? 1, text: String(m.2)))
                i += 1; continue
            }

            // Blockquote
            if let m = line.firstMatch(of: /^>\s?(.*)$/) {
                flushPara()
                blocks.append(.quote(String(m.1)))
                i += 1; continue
            }

            // Blank line = paragraph boundary
            if line.isEmpty {
                flushPara()
                i += 1; continue
            }

            paraBuf.append(raw)
            i += 1
        }
        flushPara()
        return blocks
    }

    /// Inline formatting: **bold** *italic* `code` [link]()
    /// The built-in AttributedString is good enough for this part
    static func inline(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        ))) ?? AttributedString(s)
    }
}

// MARK: - Rendering

struct MarkdownView: View {
    @Environment(\.theme) var th
    let source: String

    private var blocks: [MDBlock] { MDParser.parse(source) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                block(b)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func block(_ b: MDBlock) -> some View {
        switch b {
        case .heading(let level, let text):
            Text(MDParser.inline(text))
                .font(level == 1 ? Metric.mdH1 : (level == 2 ? Metric.mdH2 : Metric.mdH3))
                .foregroundStyle(th.ink)
                .padding(.top, level == 1 ? 20 : 16)
                .padding(.bottom, 6)
                .textSelection(.enabled)

        case .paragraph(let text):
            Text(MDParser.inline(text))
                .font(Metric.mdBody)
                .foregroundStyle(th.ink)
                .lineSpacing(4.5)
                .padding(.vertical, 5)
                .textSelection(.enabled)

        case .bullet(let text, let checked):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let checked {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 11))
                        .foregroundStyle(checked ? th.state(.inProgress) : th.ink4)
                } else {
                    Circle()
                        .fill(th.ink3)
                        .frame(width: 4, height: 4)
                        .offset(y: -1)
                }
                Text(MDParser.inline(text))
                    .font(Metric.mdBody)
                    .foregroundStyle(checked == true ? th.ink3 : th.ink)
                    .strikethrough(checked == true, color: th.ink4)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 2.5)
            .padding(.leading, 2)

        case .ordered(let idx, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(idx).")
                    .font(Metric.mdBody.monospacedDigit())
                    .foregroundStyle(th.ink3)
                    .frame(minWidth: 16, alignment: .trailing)
                Text(MDParser.inline(text))
                    .font(Metric.mdBody)
                    .foregroundStyle(th.ink)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 2.5)

        case .code(let lang, let body):
            VStack(alignment: .leading, spacing: 0) {
                if let lang {
                    Text(lang)
                        .font(Metric.micro)
                        .foregroundStyle(th.ink4)
                        .padding(.horizontal, 10)
                        .padding(.top, 7)
                }
                Text(body)
                    .font(Metric.mdCode)
                    .foregroundStyle(th.ink2)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(th.card, in: RoundedRectangle(cornerRadius: Metric.radiusSm))
            .overlay(RoundedRectangle(cornerRadius: Metric.radiusSm).strokeBorder(th.line))
            .padding(.vertical, 7)

        case .quote(let text):
            HStack(spacing: 10) {
                Rectangle().fill(th.line).frame(width: 2.5)
                Text(MDParser.inline(text))
                    .font(Metric.mdBody)
                    .foregroundStyle(th.ink2)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            }
            .padding(.vertical, 5)

        case .divider:
            Rectangle()
                .fill(th.line)
                .frame(height: 1)
                .padding(.vertical, 13)

        case .blank:
            Color.clear.frame(height: 0)
        }
    }
}
