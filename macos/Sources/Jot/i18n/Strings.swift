import Foundation

/// UI string tables.
///
/// Currently English and Simplified Chinese. Adding a language = adding a table to tables + a case to Language;
/// call sites don't change (they all go through L.xxx).
enum Language: String, CaseIterable {
    case en
    case zhHans = "zh-Hans"

    var locale: Locale {
        switch self {
        case .en:     return Locale(identifier: "en_US")
        case .zhHans: return Locale(identifier: "zh_CN")
        }
    }

    /// Each language in its own name, untranslated, so people can find their native language without reading the current UI language
    var display: String {
        switch self {
        case .en:     return "English"
        case .zhHans: return "简体中文"
        }
    }
}

/// Keys for all UI strings.
/// An enum instead of bare strings, so missing translations are caught at compile time.
enum S: String {
    case requirements, toggleSidebar, closePanel, dismissMessage, undoAction
    case markReady, startWork, sendReview, markComplete, moreActions
    case requirementsSearch, noMatches, clearSearch, history, progress
    case previewMode, editMode, unsaved, retry, editBody, discardChanges, keepEditing
    case copyRequirement, requirementCopied
    case projectShortcutHint
    case projectOrderHint, noProjects, moveProjectUp, moveProjectDown
    case projectName, renameProject, renameProjectHint
    case removeProject, removeProjectTitle, removeProjectMessage
    case repositoryURL, repositoryURLHint, openRepository, copyLink, unlink
    // Sidebar
    case navProjects

    // States
    case stInbox, stReady, stInProgress, stReview, stDone, stArchived
    case hintInbox, hintReady, hintInProgress, hintReview, hintDone, hintArchived

    // Board
    case board, clearFilter
    case emptyInbox, emptyReady, emptyInProgress, emptyReview, emptyDone, emptyArchived

    // Actions

    case actArchive, actRestore, actSave, actRevert
    case actCancel, actCreate, actChangeState, actChangeProject
    case actRename, renameTitle

    // Detail

    case metaOrigin
    case metaCreated, metaUpdated
    case metaInfo, requirementID, copyID, editTitleHint, titleRequired
    case metaTags, addTag, addTagHint, removeTag, noTags, filterByTag

    case unassigned, none_

    // New

    // Badges

    // Theme
    case appearance, exportTemplate, rescan

    // Settings
    case setGeneral, setAppearance, setShortcuts

    case setLanguage, setLanguageHint
    case shortcutBoard, shortcutInbox, shortcutReady
    case shortcutInProgress, shortcutReview, shortcutSearch
    case shortcutRefresh, shortcutInspector, shortcutBack, shortcutReset, shortcutConflict
}

@MainActor
enum L {
    static var current: Language = {
        if let raw = UserDefaults.standard.string(forKey: "jot.lang"),
           let lang = Language(rawValue: raw) { return lang }
        return .en
    }()

    static func set(_ lang: Language) {
        current = lang
        UserDefaults.standard.set(lang.rawValue, forKey: "jot.lang")
    }

    static subscript(_ key: S) -> String {
        table(current)[key] ?? en[key] ?? key.rawValue
    }

    /// Localized entries with placeholders.
    static subscript(_ key: S, _ args: CVarArg...) -> String {
        String(format: L[key], locale: current.locale, arguments: args)
    }

    static func shortDate(_ iso: String) -> String {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fractional.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }

        let formatter = DateFormatter()
        formatter.locale = current.locale
        formatter.timeZone = .current
        formatter.dateFormat = current == .zhHans ? "M月d日 HH:mm" : "MMM d, HH:mm"
        return formatter.string(from: date)
    }

    private static func table(_ lang: Language) -> [S: String] {
        switch lang {
        case .en:     return en
        case .zhHans: return zhHans
        }
    }

    private static let en: [S: String] = [
        .requirements: "Requirements",
        .toggleSidebar: "Toggle sidebar", .closePanel: "Close details", .dismissMessage: "Dismiss",
        .undoAction: "Undo", .markReady: "Mark ready", .startWork: "Start work",
        .sendReview: "Send to review", .markComplete: "Mark complete", .moreActions: "More actions",

        .requirementsSearch: "Search requirements",
        .noMatches: "No matching results",
        .clearSearch: "Clear search",
        .history: "History",
        .editBody: "Edit description", .discardChanges: "Discard changes", .keepEditing: "Keep editing",
        .copyRequirement: "Copy requirement", .requirementCopied: "Copied",
        .projectOrderHint: "Drag rows or use arrows to reorder the sidebar. Shortcuts follow positions 1–9; click a shortcut to change it.",
        .noProjects: "No projects yet", .moveProjectUp: "Move up", .moveProjectDown: "Move down",
        .projectName: "Project name", .renameProject: "Rename project",
        .renameProjectHint: "Its requirement files move to the new folder name.",
        .removeProject: "Remove project", .removeProjectTitle: "Remove “%@”?",
        .removeProjectMessage: "%d requirements (including done and archived) will become unassigned. Their status and bodies are kept, and no repository or file is deleted. Capturing inside this repository again registers the project again.",
        .repositoryURL: "Repository URL",
        .repositoryURLHint: "Leave empty to use the origin remote of the project folder.",
        .openRepository: "Open repository", .copyLink: "Copy link", .unlink: "Unlink",
        .projectShortcutHint: "Switch to projects 1–9 in sidebar order. Hold Option to see shortcuts; click a key to customize.",
        .progress: "Progress",

        .previewMode: "Preview", .editMode: "Edit", .unsaved: "Unsaved changes",
        .retry: "Retry",

        .navProjects:  "Projects",

        // Title case. All caps is too loud in body-text spots like the sidebar,
        // and clashes with the style of All and project names
        .stInbox:    "Inbox",
        .stReady:    "Ready",
        .stInProgress: "In Progress",

        .stReview:   "On Hold",
        .stDone:     "Done",
        .stArchived: "Archived",

        .hintInbox:    "not started",
        .hintReady:    "ready to work",
        .hintInProgress: "being worked on",

        .hintReview:   "paused or waiting",
        .hintDone:     "completed",
        .hintArchived: "archived",

        .board:       "Board",

        .clearFilter: "Clear filter",

        .emptyInbox:   "Inbox is empty",
        .emptyReady:   "No requirements ready to start",
        .emptyInProgress: "Nothing in progress",

        .emptyReview:  "Nothing on hold",

        .emptyDone:    "No completed requirements",
        .emptyArchived: "No archived requirements",

        .actArchive:       "Archive",
        .actRestore:       "Restore",

        .actSave:          "Save",
        .actRevert:        "Revert",
        .actCancel:        "Cancel",
        .actCreate:        "Create",
        .actChangeState:   "Move to",
        .actRename:        "Rename…",
        .renameTitle:      "Rename request",

        .actChangeProject: "Project",

        .metaOrigin:  "Captured in",

        .metaCreated: "Created",
        .metaUpdated: "Updated",
        .metaInfo:      "Info",
        .metaTags:      "Tags",
        .addTag:        "Add tag",
        .addTagHint:    "Tag name, e.g. v1.2.0",
        .removeTag:     "Remove tag",
        .filterByTag:   "Filter by this tag",
        .noTags:        "No tags",
        .requirementID: "Requirement ID",
        .copyID: "Copy ID",
        .editTitleHint: "Double-click to edit title",
        .titleRequired: "Title cannot be empty",

        .unassigned:  "Unassigned",
        .none_:       "None",



        .appearance:     "Appearance",
        .exportTemplate: "Export template",
        .rescan:         "Rescan",

        .setGeneral:      "General",
        .setAppearance:   "Appearance",
        .setShortcuts:    "Keyboard Shortcuts",

        .shortcutBoard:       "Show Board",
        .shortcutInbox:       "Inbox",
        .shortcutReady:       "Ready",
        .shortcutInProgress:  "In Progress",
        .shortcutReview:      "On Hold",

        .shortcutSearch:      "Search requirements",
        .shortcutRefresh:     "Refresh",
        .shortcutInspector:   "Show or Hide Side Panel",
        .shortcutBack:        "Go Back",
        .shortcutReset:       "Restore Defaults",
        .shortcutConflict:    "Already assigned to %@",
        .setLanguage:     "Language",
        .setLanguageHint: "Takes effect immediately",
    ]

    private static let zhHans: [S: String] = [
        .requirements: "需求",
        .toggleSidebar: "展开或收起侧栏", .closePanel: "关闭详情", .dismissMessage: "关闭提示",
        .undoAction: "撤销", .markReady: "标记就绪", .startWork: "开始处理",
        .sendReview: "提交验收", .markComplete: "标记完成", .moreActions: "更多操作",

        .requirementsSearch: "搜索需求",
        .noMatches: "没有匹配的结果",
        .clearSearch: "清除搜索",
        .history: "历史",
        .editBody: "编辑正文", .discardChanges: "放弃修改", .keepEditing: "继续编辑",
        .copyRequirement: "复制需求", .requirementCopied: "已复制",
        .projectOrderHint: "拖动行或使用箭头调整侧栏顺序。快捷键对应前 9 个位置，点击组合键可修改。",
        .noProjects: "暂无项目", .moveProjectUp: "上移", .moveProjectDown: "下移",
        .projectName: "项目名称", .renameProject: "重命名项目",
        .renameProjectHint: "需求文件会随之移动到新名称的目录。",
        .removeProject: "删除项目", .removeProjectTitle: "删除「%@」？",
        .removeProjectMessage: "%d 条需求（含已完成和归档）将变为无项目，状态和正文保留，不会删除仓库或任何文件。之后在该仓库内再次录入需求，会重新注册这个项目。",
        .repositoryURL: "仓库地址",
        .repositoryURLHint: "留空则使用项目目录的 origin 远程地址。",
        .openRepository: "打开仓库", .copyLink: "复制链接", .unlink: "解除绑定",
        .projectShortcutHint: "按侧栏顺序切换前 9 个项目。按住 Option 查看提示，点击组合键可修改。",
        .progress: "进度",

        .previewMode: "预览", .editMode: "编辑", .unsaved: "有未保存的修改",
        .retry: "重试",

        .navProjects:  "项目",

        .stInbox:    "收件箱",
        .stReady:    "待处理",
        .stInProgress: "进行中",

        .stReview:   "暂缓",
        .stDone:     "已完成",
        .stArchived: "已归档",

        .hintInbox:    "等你整理",
        .hintReady:    "已整理，可以开始处理",
        .hintInProgress: "正在处理",

        .hintReview:   "暂停处理或等待条件满足",
        .hintDone:     "已完成",
        .hintArchived: "已归档",

        .board:       "看板",

        .clearFilter: "清除筛选",

        .emptyInbox:    "暂无待整理需求",
        .emptyReady:    "暂无待开始需求",
        .emptyInProgress: "暂无进行中的需求",

        .emptyReview:   "暂无暂缓需求",

        .emptyDone:     "暂无已完成需求",
        .emptyArchived: "暂无已归档需求",

        .actArchive:       "归档",
        .actRestore:       "恢复",

        .actSave:          "保存",
        .actRevert:        "还原",
        .actCancel:        "取消",
        .actCreate:        "创建",
        .actChangeState:   "移动到",
        .actRename:        "重命名…",
        .renameTitle:      "重命名需求",

        .actChangeProject: "项目",

        .metaOrigin:  "录入于",

        .metaCreated: "创建于",
        .metaUpdated: "更新于",
        .metaInfo:      "信息",
        .metaTags:      "标签",
        .addTag:        "添加标签",
        .addTagHint:    "标签名，如 v1.2.0",
        .removeTag:     "移除标签",
        .filterByTag:   "按此标签筛选",
        .noTags:        "暂无标签",
        .requirementID: "需求编号",
        .copyID: "复制编号",
        .editTitleHint: "双击编辑标题",
        .titleRequired: "标题不能为空",

        .unassigned:  "未指派",
        .none_:       "无",



        .appearance:     "外观",
        .exportTemplate: "导出模板",
        .rescan:         "重新扫描",

        .setGeneral:      "通用",
        .setAppearance:   "外观",
        .setShortcuts:    "键盘快捷键",

        .shortcutBoard:       "显示看板",
        .shortcutInbox:       "收件箱",
        .shortcutReady:       "就绪",
        .shortcutInProgress:  "进行中",
        .shortcutReview:      "暂缓",

        .shortcutSearch:      "搜索需求",
        .shortcutRefresh:     "刷新",
        .shortcutInspector:   "显示或隐藏侧边面板",
        .shortcutBack:        "返回",
        .shortcutReset:       "恢复默认",
        .shortcutConflict:    "已分配给「%@」",
        .setLanguage:     "语言",
        .setLanguageHint: "立即生效",
    ]
}

/// Observable carrier for language switching.
///
/// L.current is a static var; changing it doesn't make SwiftUI redraw.
/// Wrapping it in an ObservableObject injected at the root view
/// refreshes the whole tree on switch, no app restart needed.
@MainActor
final class LocaleStore: ObservableObject {
    @Published private(set) var language: Language = L.current

    func select(_ lang: Language) {
        guard lang != language else { return }
        L.set(lang)
        language = lang
    }
}
