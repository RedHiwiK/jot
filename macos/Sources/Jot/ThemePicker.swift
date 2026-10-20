import SwiftUI
import AppKit

/// Theme picker. Modeled on Otty's Appearance page: thumbnail grid + selection frame.
struct ThemePicker: View {
    @EnvironmentObject var themes: ThemeStore
    @Environment(\.theme) var th
    @Environment(\.dismiss) var dismiss

    private let cols = [GridItem(.adaptive(minimum: 132), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L[.appearance]).font(Metric.body.weight(.semibold)).foregroundStyle(th.ink)
                Spacer()
                IconButton(icon: "xmark", size: 10) { dismiss() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            HLine()

            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(themes.available, id: \.name) { entry in
                        Swatch(
                            name: entry.name,
                            palette: entry.palette,
                            selected: themes.current.name == entry.name
                        )
                        .onTapGesture { themes.select(entry.name) }
                    }
                }
                .padding(14)
            }

            HLine()

            HStack(spacing: 8) {
                Button(L[.exportTemplate]) {
                    if let url = themes.exportTemplate() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
                .buttonStyle(FlatButton(compact: true))

                Button(L[.rescan]) { themes.reload() }
                    .buttonStyle(FlatButton(compact: true))

                Spacer()

                Text("~/.jot/themes/*.json")
                    .font(Metric.micro)
                    .foregroundStyle(th.ink4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 480, height: 400)
        .background(th.canvas)
    }
}

/// Theme thumbnail: a few color blocks hint at the actual look
struct Swatch: View {
    @Environment(\.theme) var th
    let name: String
    let palette: Palette
    let selected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: Metric.radiusSm)
                    .fill(Color(hex: palette.canvas))

                HStack(spacing: 0) {
                    // Sidebar preview
                    VStack(alignment: .leading, spacing: 3) {
                        bar(palette.ink3, 18)
                        bar(palette.ink4, 14)
                        bar(palette.ink4, 16)
                    }
                    .padding(6)
                    .frame(width: 34, alignment: .leading)
                    .frame(maxHeight: .infinity)
                    .background(Color(hex: palette.sidebar))

                    // Card preview
                    VStack(alignment: .leading, spacing: 4) {
                        card(palette.ready)
                        card(palette.running)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .clipShape(RoundedRectangle(cornerRadius: Metric.radiusSm))
            }
            .frame(height: 76)
            .overlay(
                RoundedRectangle(cornerRadius: Metric.radiusSm)
                    .strokeBorder(selected ? th.accent : Color(hex: palette.line),
                                  lineWidth: selected ? 2 : 1)
            )

            Text(name)
                .font(Metric.micro)
                .foregroundStyle(selected ? th.ink : th.ink3)
        }
    }

    private func bar(_ hex: String, _ w: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(hex: hex).opacity(0.55))
            .frame(width: w, height: 2.5)
    }

    private func card(_ accent: String) -> some View {
        HStack(spacing: 3) {
            Circle().fill(Color(hex: accent)).frame(width: 3, height: 3)
            VStack(alignment: .leading, spacing: 2) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: palette.ink).opacity(0.5)).frame(height: 2.5)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: palette.ink4).opacity(0.6))
                    .frame(width: 22, height: 2)
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: palette.card), in: RoundedRectangle(cornerRadius: 2.5))
        .overlay(RoundedRectangle(cornerRadius: 2.5).strokeBorder(Color(hex: palette.line)))
    }
}
