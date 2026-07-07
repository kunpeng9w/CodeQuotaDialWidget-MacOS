import SwiftUI

/// 设计系统 token。
///
/// 动效准则：数值变化用 `.snappy`；圆环填充 `.easeOut(0.6)`；hover 0.12s；
/// 滚动过程中不做布局动画；所有动画受 `accessibilityReduceMotion` 门控。
enum DS {
    /// 4pt 间距网格，取代零散的 18/12/16/24。
    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 20
        static let xl: CGFloat = 24
    }

    enum Radius {
        static let card: CGFloat = 12
        static let control: CGFloat = 8
        static let chip: CGFloat = 6
    }

    /// 字体阶梯——面板文本只允许从这里取。
    enum Typo {
        /// 英雄数字（总览今日消耗）。
        static let metricXL = Font.system(size: 34, weight: .bold, design: .rounded)
        /// 卡片主数值。
        static let metricL = Font.system(size: 26, weight: .bold, design: .rounded)
        /// KPI 数值。
        static let metricM = Font.system(size: 17, weight: .semibold, design: .rounded)
        /// 面板头部标题。
        static let panelTitle = Font.title2.weight(.semibold)
        /// 卡片/区块小标签（配 .secondary + uppercase）。
        static let cardLabel = Font.caption.weight(.semibold)
        /// 三级脚注。
        static let meta = Font.caption2
    }

    /// 卡片层级模型：面板背景是「平的」窗口底色，卡片是唯一抬升层。
    enum Elevation {
        case flat
        case raised
        case prominent
    }
}
