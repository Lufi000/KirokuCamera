import SwiftUI

// MARK: - Kiroku Camera 设计系统
//
// 【UI 调整入口】改 UI 时优先改本文件，再配合 Canvas 预览看效果：
//   • 颜色：下方 KirokuColors（主色、背景、文字等）
//   • 圆角/间距：下方 KirokuLayout（卡片、按钮、内边距）
//   • 返回按钮：SubjectDetailView / CompareView 里 toolbar 的 .foregroundStyle(Color.kiroku.primary)
//   • 实时预览：打开 Theme/KirokuThemePreview.swift → 菜单 Editor → Canvas（或 ⌥⌘P）→ 改本文件后 Canvas 会刷新
//
// 主题色：925BC1 / 3E5AD0 / FF6E24；背景色：C0D3BD / FAEDD8

extension Color {
    static let kiroku = KirokuColors()
}

// MARK: - 布局常量（圆角、间距）

struct KirokuLayout {
    /// 小卡片/网格单元格圆角（如网格照片卡）
    static let cardCornerRadiusSmall: CGFloat = 14
    /// 大卡片/时间线卡片圆角
    static let cardCornerRadiusLarge: CGFloat = 20
    /// 列表内图片圆角
    static let imageCornerRadius: CGFloat = 12
    /// 封面标签圆角（与所在卡片一致：网格 14，时间线 20，见各 View）
    static let tagCornerRadiusGrid: CGFloat = 14
    static let tagCornerRadiusTimeline: CGFloat = 20
    /// 页面内边距
    static let pagePadding: CGFloat = 16
    /// 卡片内边距
    static let cardPadding: CGFloat = 16
}

struct KirokuColors {
    // MARK: - 背景色

    /// 主背景 #FAEDD8
    let background = Color(red: 250/255, green: 237/255, blue: 216/255)

    /// 卡片/区块背景 #C0D3BD
    let surface = Color(red: 192/255, green: 211/255, blue: 189/255)

    // MARK: - 主题色

    /// 主色 #925BC1
    let primary = Color(red: 146/255, green: 91/255, blue: 193/255)

    /// 辅色蓝 #3E5AD0
    let secondary = Color(red: 62/255, green: 90/255, blue: 208/255)

    /// 强调色橙 #FF6E24
    let accent = Color(red: 255/255, green: 110/255, blue: 36/255)

    /// 兼容旧命名
    let logoBlue = Color(red: 62/255, green: 90/255, blue: 208/255)
    let logoGreen = Color(red: 192/255, green: 211/255, blue: 189/255)

    /// 浅色块（占位/未选）用 surface 淡色
    let lightPink = Color(red: 192/255, green: 211/255, blue: 189/255).opacity(0.6)

    // MARK: - 文字色彩

    /// 主文字色 - 深灰（不用纯黑）#4A4A4A
    let textPrimary = Color(red: 74/255, green: 74/255, blue: 74/255)

    /// 次要文字色 - 中灰 #8E8E93
    let textSecondary = Color(red: 142/255, green: 142/255, blue: 147/255)

    // MARK: - 卡片（透明、与背景和谐）

    /// 卡片填充：半透明白，叠在背景上呈柔和浅层，与 FAEDD8/C0D3BD 协调
    let cardFill = Color.white.opacity(0.5)

    /// 卡片描边：与背景同色系的淡边
    let glassBorder = Color.white.opacity(0.7)

    /// 分隔线 - 浅灰
    let divider = Color(red: 230/255, green: 230/255, blue: 235/255)

    // MARK: - 阴影色

    /// 柔和阴影色
    let shadow = Color.black.opacity(0.08)
}

// MARK: - 主题化按钮样式

struct KirokuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.kiroku.primary)
                    .shadow(color: Color.kiroku.shadow, radius: 8, x: 0, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct KirokuSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(Color.kiroku.primary)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color.kiroku.cardFill)
                    .overlay(
                        Capsule()
                            .stroke(Color.kiroku.primary.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == KirokuButtonStyle {
    static var kirokuPrimary: KirokuButtonStyle { KirokuButtonStyle() }
}

extension ButtonStyle where Self == KirokuSecondaryButtonStyle {
    static var kirokuSecondary: KirokuSecondaryButtonStyle { KirokuSecondaryButtonStyle() }
}

// MARK: - 玻璃卡片样式

/// 玻璃拟态卡片容器（毛玻璃材质）
struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.kiroku.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.kiroku.glassBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.kiroku.shadow, radius: 20, x: 0, y: 10)
            )
    }
}

/// 兼容旧代码的卡片（使用新样式）
struct KirokuCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GlassCard {
            content
        }
    }
}

// MARK: - 玻璃背景修饰器

struct GlassBackgroundModifier: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.kiroku.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.kiroku.glassBorder, lineWidth: 0.5)
                    )
            )
    }
}

extension View {
    /// 应用玻璃背景效果
    func glassBackground(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassBackgroundModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 页面背景修饰器

struct KirokuPageBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.kiroku.background.ignoresSafeArea())
    }
}

extension View {
    /// 应用 Kiroku Camera 风格页面背景
    func kirokuBackground() -> some View {
        modifier(KirokuPageBackground())
    }
}
