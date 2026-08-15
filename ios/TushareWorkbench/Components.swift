import SwiftUI
import TushareWorkbenchCore

enum Palette {
    static let bg = Color(red: 0.055, green: 0.063, blue: 0.075)
    static let card = Color(red: 0.09, green: 0.10, blue: 0.125)
    static let card2 = Color(red: 0.113, green: 0.129, blue: 0.16)
    static let line = Color(red: 0.15, green: 0.17, blue: 0.20)
    static let text = Color(red: 0.91, green: 0.92, blue: 0.93)
    static let muted = Color(red: 0.60, green: 0.64, blue: 0.68)
    static let accent = Color(red: 0.29, green: 0.64, blue: 1.0)
}

func chipColor(_ label: String) -> Color {
    switch label {
    case "强", "持续强势", "启动观察": return Color(red: 1.0, green: 0.36, blue: 0.36)
    case "正在加强", "趋势观察": return Color(red: 1.0, green: 0.56, blue: 0.24)
    case "开始活跃": return Color(red: 0.29, green: 0.64, blue: 1.0)
    case "正常": return Color(red: 0.94, green: 0.71, blue: 0.16)
    case "偏弱", "走弱": return Color(red: 0.23, green: 0.66, blue: 0.46)
    case "高位观察": return Color(red: 0.69, green: 0.48, blue: 1.0)
    case "回调观察": return Color(red: 0.29, green: 0.64, blue: 1.0)
    case "数据不足": return Color(red: 0.82, green: 0.65, blue: 0.25)
    default: return Palette.muted
    }
}

struct Chip: View {
    let label: String
    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(chipColor(label))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .overlay(
                Capsule().stroke(chipColor(label), lineWidth: 1)
            )
    }
}

struct AppCard<Content: View>: View {
    var title: String?
    var right: AnyView?
    @ViewBuilder let content: Content

    init(title: String? = nil, right: AnyView? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.right = right
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if title != nil || right != nil {
                HStack {
                    if let title {
                        Text(title).font(.system(size: 14, weight: .semibold))
                    }
                    Spacer()
                    if let right { right }
                }
            }
            content
        }
        .padding(12)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Palette.line, lineWidth: 1)
        )
    }
}

struct ReasonList: View {
    let reasons: [ReasonItem]
    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(reasons.enumerated()), id: \.offset) { _, r in
                HStack(spacing: 6) {
                    Text(r.pass ? "✓" : "✗")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(r.pass ? Color.green : Color.red)
                    Text(r.label).font(.system(size: 12))
                    Spacer()
                    if let value = r.value {
                        Text(String(format: "%.2f", value))
                            .font(.system(size: 12, weight: .semibold))
                            .monospacedDigit()
                    }
                    if !r.threshold.isEmpty {
                        Text(r.threshold).font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Palette.card2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                if !r.note.isEmpty {
                    Text(r.note).font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

struct Sparkline: View {
    let values: [Double?]
    var body: some View {
        GeometryReader { geo in
            let vals = values.compactMap { $0 }.suffix(60)
            if vals.count >= 2, let minV = vals.min(), let maxV = vals.max() {
                let range = maxV - minV > 0 ? maxV - minV : 1
                Path { p in
                    for (i, v) in vals.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(vals.count - 1)
                        let y = geo.size.height -
                            CGFloat((v - minV) / range) * (geo.size.height - 4) - 2
                        if i == 0 {
                            p.move(to: CGPoint(x: x, y: y))
                        } else {
                            p.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Palette.accent, lineWidth: 1.2)
            }
        }
    }
}

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Palette.accent : Color.clear)
                .foregroundStyle(isActive ? Color.white : Palette.muted)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Palette.line, lineWidth: 1))
        }
    }
}

func fmt(_ v: Double?) -> String {
    guard let v else { return "—" }
    return String(format: "%.2f", v)
}

func fmt1(_ v: Double?) -> String {
    guard let v else { return "—" }
    return String(format: "%.1f", v)
}
