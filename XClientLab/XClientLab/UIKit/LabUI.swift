import UIKit

/// UIKit 版本的视觉令牌。
///
/// 从 SwiftUI design system 迁移时保留同一套色值、字号与间距，避免“换成 UIKit
/// 后像另一个产品”。所有页面只读这里的 token，不直接写 UIColor/字号。
enum LabUI {
    // Canvas
    static let backgroundTop = UIColor(red: 0.027, green: 0.035, blue: 0.055, alpha: 1)
    static let backgroundBottom = UIColor(red: 0.047, green: 0.059, blue: 0.086, alpha: 1)
    static let surface = UIColor(red: 0.071, green: 0.086, blue: 0.122, alpha: 1)
    static let surfaceRaised = UIColor(red: 0.094, green: 0.114, blue: 0.157, alpha: 1)

    // Accents
    static let cyan = UIColor(red: 0.231, green: 0.831, blue: 0.933, alpha: 1)
    static let mint = UIColor(red: 0.345, green: 0.925, blue: 0.690, alpha: 1)
    static let amber = UIColor(red: 1.000, green: 0.741, blue: 0.302, alpha: 1)
    static let coral = UIColor(red: 1.000, green: 0.455, blue: 0.420, alpha: 1)
    static let violet = UIColor(red: 0.663, green: 0.563, blue: 1.000, alpha: 1)
    static let steel = UIColor(red: 0.545, green: 0.604, blue: 0.694, alpha: 1)

    // Text
    static let textPrimary = UIColor(red: 0.941, green: 0.957, blue: 0.984, alpha: 1)
    static let textSecondary = UIColor(red: 0.624, green: 0.671, blue: 0.749, alpha: 1)
    static let textTertiary = UIColor(red: 0.420, green: 0.467, blue: 0.545, alpha: 1)
    static let hairline = UIColor.white.withAlphaComponent(0.08)

    // Spacing
    static let pageInset: CGFloat = 18
    static let cardRadius: CGFloat = 20
    static let sectionSpacing: CGFloat = 18

    static func font(
        _ size: CGFloat,
        weight: UIFont.Weight = .regular,
        mono: Bool = false,
        rounded: Bool = false
    ) -> UIFont {
        var font = mono
            ? UIFont.monospacedSystemFont(ofSize: size, weight: weight)
            : UIFont.systemFont(ofSize: size, weight: weight)
        if rounded, let descriptor = font.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: size)
        }
        return font
    }

    static func applyAppearance() {
        let navigation = UINavigationBarAppearance()
        navigation.configureWithOpaqueBackground()
        navigation.backgroundColor = backgroundTop
        navigation.shadowColor = .clear
        navigation.titleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: font(14, weight: .semibold)
        ]
        navigation.largeTitleTextAttributes = [
            .foregroundColor: textPrimary,
            .font: font(30, weight: .bold, rounded: true)
        ]
        UINavigationBar.appearance().standardAppearance = navigation
        UINavigationBar.appearance().scrollEdgeAppearance = navigation
        UINavigationBar.appearance().compactAppearance = navigation
        UINavigationBar.appearance().tintColor = cyan

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.035, green: 0.043, blue: 0.067, alpha: 0.98)
        tab.shadowColor = hairline

        let item = tab.stackedLayoutAppearance
        item.normal.iconColor = UIColor(white: 0.55, alpha: 1)
        item.normal.titleTextAttributes = [
            .foregroundColor: UIColor(white: 0.55, alpha: 1),
            .font: font(10, weight: .medium)
        ]
        item.selected.iconColor = cyan
        item.selected.titleTextAttributes = [
            .foregroundColor: cyan,
            .font: font(10, weight: .semibold)
        ]

        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }

    static func accent(for module: LabModule) -> UIColor {
        switch module {
        case .performance: return cyan
        case .exceptions: return coral
        case .exchange: return mint
        case .aiNative: return violet
        case .architecture: return amber
        }
    }
}

/// Deep-space canvas with a subtle grid and a top-right accent glow.
/// UIKit 版用 Core Graphics 绘制，避免引入图片资源。
final class LabCanvasView: UIView {
    private let accent: UIColor

    init(accent: UIColor = LabUI.cyan) {
        self.accent = accent
        super.init(frame: .zero)
        isOpaque = false
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let colors = [LabUI.backgroundTop.cgColor, LabUI.backgroundBottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.midX, y: rect.minY),
                end: CGPoint(x: rect.midX, y: rect.maxY),
                options: []
            )
        }

        context.setStrokeColor(UIColor.white.withAlphaComponent(0.018).cgColor)
        context.setLineWidth(0.5)
        let spacing: CGFloat = 28
        var x: CGFloat = 0
        while x <= rect.width {
            context.move(to: CGPoint(x: x, y: 0))
            context.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        context.strokePath()

        let glowColors = [accent.withAlphaComponent(0.16).cgColor, accent.withAlphaComponent(0).cgColor] as CFArray
        if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1]) {
            let center = CGPoint(x: rect.maxX - 26, y: 70)
            context.drawRadialGradient(
                glow,
                startCenter: center,
                startRadius: 8,
                endCenter: center,
                endRadius: 360,
                options: [.drawsAfterEndLocation]
            )
        }
    }
}
