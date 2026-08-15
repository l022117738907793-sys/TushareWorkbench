import Foundation

public let learningQuestions: [String: [String]] = [
    "启动观察": [
        "你会把它放在哪个观察类型？",
        "这次上涨属于启动阶段还是趋势加速？为什么？",
        "如果接下来回调，你最希望看到价格和成交量出现什么变化？",
    ],
    "趋势观察": [
        "趋势延续最需要盯住哪个信号？",
        "如果回调，你希望看到缩量还是放量？为什么？",
        "什么情况出现会让你重新判断它不是趋势观察？",
    ],
    "高位观察": [
        "什么信号出现会让你警惕？",
        "放量滞涨说明什么？",
        "如果它开始回调，你想先看哪个指标？",
    ],
    "回调观察": [
        "回调是缩量还是放量？你认为哪种更健康？",
        "回调是否破坏了上升趋势？你用什么判断？",
        "如果重新向上突破，你想看到什么确认？",
    ],
    "排除": [
        "你觉得它被排除的主要原因是什么？",
        "什么条件变化后它值得重新进入观察？",
    ],
    "数据不足": ["缺少哪些数据会让你无法判断？"],
]

public func questions(for type: String) -> [String] {
    learningQuestions[type] ?? learningQuestions["数据不足"]!
}

private let keywordGroups: [String: [String]] = [
    "量能": ["放量", "缩量", "量比", "量能", "成交量"],
    "突破": ["突破", "新高", "站上", "站稳", "破位", "跌破"],
    "均线": ["20日", "60日", "均线", "支撑", "压力", "日线"],
    "位置": ["高位", "低位", "顶部", "底部", "位置", "回调"],
    "环境": ["大盘", "市场", "板块", "行业", "赚钱效应", "环境"],
    "节奏": ["启动", "加速", "趋势", "延续", "滞涨", "观察"],
]

public func generateLearningFeedback(
    type: String,
    answer: String,
    report: AnalysisReport,
    m: StockMetrics
) -> LearningFeedback {
    let mentioned = keywordGroups.filter { _, words in
        words.contains { answer.contains($0) }
    }.map(\.key)

    let doneRight: [String]
    if mentioned.isEmpty {
        doneRight = [
            "你给出了自己的判断方向，这是学习的第一步。",
            "接下来可以试着把判断落到具体的价格和成交量信号上。",
        ]
    } else {
        doneRight = [
            "你注意到了「\(mentioned.joined(separator: "、"))」这些因素，说明你在按量价关系思考。",
            "你没有被单一指标带偏，而是在描述价格行为，这一点很好。",
        ]
    }

    let facts: [(String, Bool)] = [
        ("量能变化（量比 \(fmt(m.volRatio))）", answer.contains("量") || answer.contains("放") || answer.contains("缩")),
        ("价格与20日线的关系（偏离 \(fmt(m.dist20))%）", ["20日", "均线", "日线", "支撑", "压力"].contains { answer.contains($0) }),
        ("距20日高点位置（\(fmt(m.distHigh))%）", ["高点", "新高", "突破", "位置"].contains { answer.contains($0) }),
        ("大盘「\(report.market.state)」与板块「\(report.sector.state)」环境", ["大盘", "市场", "板块", "行业", "环境"].contains { answer.contains($0) }),
        ("ATR 波动标记「\(m.atr.available ? m.atr.flag : "数据不足")」", ["ATR", "波动", "超跌"].contains { answer.contains($0) }),
    ]
    let easyToMiss = facts.filter { !$0.1 }.map(\.0)

    let further: [String: String] = [
        "启动观察": "启动确认靠『放量 + 位置』：没有量的突破容易是假突破；位置已经远离20日线时追入的成本和风险都会更高。",
        "趋势观察": "趋势是否健康，重点看回调时的量与20日线的方向：缩量回踩说明抛压有限，20日线持续上弯说明趋势还活着。",
        "回调观察": "回调本身不可怕，可怕的是放量下跌；你要判断的是趋势有没有被破坏，而不是单纯看跌了多少。",
        "高位观察": "高位最危险的不是上涨，而是『放量却涨不动』；滞涨意味着买盘无法继续推高，接下来要看会不会破位。",
        "排除": "排除不等于永远不会再看，而是当前价格结构不满足观察条件；先确认它重新站回关键均线，再重新进入观察。",
        "数据不足": "没有足够数据时，任何结论都是猜测；先补齐交易日和成交量数据，再谈判断。",
    ]
    return LearningFeedback(
        doneRight: doneRight,
        easyToMiss: easyToMiss,
        thinkFurther: further[type] ?? "把每个结论都落到具体的价格、成交量和位置数据上。"
    )
}

public func reviewThesis(
    _ input: ThesisInput,
    report: AnalysisReport,
    m: StockMetrics
) -> ThesisReview {
    var rows: [ThesisRow] = []
    if input.types.contains("技术形态") {
        let userSaid = input.text.contains(report.currentType)
        let otherTypes = learningQuestions.keys.filter { $0 != report.currentType }
        let conflict = otherTypes.contains { input.text.contains($0) }
        rows.append(ThesisRow(
            reasonType: "技术形态",
            systemEvidence: "系统当前归类「\(report.currentType)」：近20日涨幅 \(fmt(m.ret20))%、距20日线 \(fmt(m.dist20))%、距20日高点 \(fmt(m.distHigh))%、量比 \(fmt(m.volRatio))",
            conclusion: userSaid ? "一致" : (conflict ? "冲突" : "未覆盖")
        ))
    }
    if input.types.contains("消息催化") {
        rows.append(ThesisRow(reasonType: "消息催化",
                              systemEvidence: "快照没有新闻/公告数据",
                              conclusion: "数据不足，不许编造"))
    }
    if input.types.contains("基本面") {
        rows.append(ThesisRow(reasonType: "基本面",
                              systemEvidence: "快照没有财务数据",
                              conclusion: "数据不足"))
    }
    if input.types.contains("资金流向") {
        rows.append(ThesisRow(reasonType: "资金流向",
                              systemEvidence: "快照没有资金流数据",
                              conclusion: "数据不足"))
    }
    if input.types.contains("情绪博弈") {
        let active = ge(m.volRatio, 1.2)
        rows.append(ThesisRow(
            reasonType: "情绪博弈",
            systemEvidence: "板块赚钱效应：上涨占比约 \(fmt((report.sector.breadth20 ?? 0) * 100))%、强势股 \(report.sector.strongCount) 只；个股量比 \(fmt(m.volRatio))",
            conclusion: active ? "一致（量能支持情绪面）" : "未覆盖（量能未见明显放大）"
        ))
    }
    let horizonMap: [String: (Double?, String)] = [
        "短线": (m.ret5, "近5日涨跌幅"),
        "波段": (m.ret20, "近20日涨跌幅"),
        "中线": (m.ret60, "近60日涨跌幅"),
    ]
    let (hVal, hLabel) = horizonMap[input.horizon] ?? (nil, "")
    rows.append(ThesisRow(
        reasonType: "时间预期（\(input.horizon)）",
        systemEvidence: "\(hLabel) \(fmt(hVal))%",
        conclusion: hVal == nil ? "数据不足" : (hVal! > 0 ? "一致（该窗口表现为正）" : "冲突（该窗口表现为负）")
    ))
    return ThesisReview(
        rows: rows,
        followUp: "你的判断和系统依据有哪些地方不一样？试着说出系统可能没看到、但你看到了的因素。"
    )
}
