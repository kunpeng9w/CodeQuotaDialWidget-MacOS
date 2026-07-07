import Foundation

/// 全 app 统一的展示格式化，取代 UsagePanelView / Sub2APIQuotaPanelView /
/// ModelPricesPanelView 里的三份私有拷贝。

func dsCost(_ value: Double?) -> String {
    guard let value else { return "$--" }
    return String(format: "$%.2f", value)
}

/// 限额是整数（$160 / $800）时省掉小数。
func dsLimitCost(_ value: Double) -> String {
    value == value.rounded() ? String(format: "$%.0f", value) : String(format: "$%.2f", value)
}

func dsCompactNumber(_ value: Int?) -> String {
    guard let value else { return "--" }
    let number = Double(value)
    if number >= 1_000_000_000 {
        return String(format: "%.1fB", number / 1_000_000_000)
    }
    if number >= 1_000_000 {
        return String(format: "%.1fM", number / 1_000_000)
    }
    if number >= 1_000 {
        return String(format: "%.1fK", number / 1_000)
    }
    return "\(value)"
}

func dsWeekdayShort(_ period: String) -> String {
    guard let date = dsDayFormatter.date(from: period) else { return "" }
    let index = Calendar.current.component(.weekday, from: date)
    let labels = ["日", "一", "二", "三", "四", "五", "六"]
    return labels[max(0, min(6, index - 1))]
}

let dsDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

let dsResetFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "MM-dd HH:mm"
    return formatter
}()
