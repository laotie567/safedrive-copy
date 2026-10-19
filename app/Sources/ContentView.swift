import AppKit

// ==========================================================================
// ContentView —— 单窗口主界面（布局 / 配色 / 文案照抄 prd-demo 定稿稿）
// ==========================================================================

// MARK: - 调色板（与 demo CSS 变量一一对应）

enum Pal {
    static let bg = NSColor.hex("#f4f6f8")
    static let panel = NSColor.hex("#ffffff")
    static let ink = NSColor.hex("#1a2b3c")
    static let sub = NSColor.hex("#5b7186")
    static let hint = NSColor.hex("#8aa0b2")
    static let empty = NSColor.hex("#9ab0c0")
    static let accent = NSColor.hex("#0e9f8a")
    static let accentDeep = NSColor.hex("#0b7f6e")
    static let accentSoft = NSColor.hex("#e3f5f1")
    static let accentGrad2 = NSColor.hex("#22b8a5")
    static let accentBorder = NSColor.hex("#bfe5dd")
    static let dzBorder = NSColor.hex("#bfd4cd")
    static let dzBase = NSColor.hex("#fafcfb")
    static let dzStripe = NSColor.hex("#f4f9f7")
    static let line = NSColor.hex("#e3e9ee")
    static let hairline = NSColor.hex("#f0f4f6")
    static let warn = NSColor.hex("#b45309")
    static let warnLed = NSColor.hex("#d97706")
    static let warnBg = NSColor.hex("#fff7e6")
    static let warnBorder = NSColor.hex("#f2dfb6")
    static let ok = NSColor.hex("#15803d")
    static let reportBg = NSColor.hex("#f2fbf7")
    static let reportBorder = NSColor.hex("#cdeadd")
    static let danger = NSColor.hex("#b91c1c")
    static let cancelBg = NSColor.hex("#fef2f2")
    static let cancelBorder = NSColor.hex("#fecaca")
    static let skipGray = NSColor.hex("#64748b")
    static let runBg = NSColor.hex("#e0f2fe")
    static let runFg = NSColor.hex("#0369a1")
    static let doneBg = NSColor.hex("#dcfce7")
    static let waitBg = NSColor.hex("#eef2f5")
    static let skipBg = NSColor.hex("#f1f5f9")
    static let failBg = NSColor.hex("#fee2e2")
    static let ghostBg = NSColor.hex("#f1f5f7")
    static let disabledBg = NSColor.hex("#c3d4d0")
}

extension NSColor {
    static func hex(_ s: String) -> NSColor {
        let h = s.hasPrefix("#") ? String(s.dropFirst()) : s
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255.0,
                       green: CGFloat((v >> 8) & 0xff) / 255.0,
                       blue: CGFloat(v & 0xff) / 255.0, alpha: 1)
    }
}

// MARK: - 格式化

func fmtBytes(_ n: Int64) -> String {
    let d = Double(n)
    if d < 1024 { return "\(n) B" }
    if d < 1048576 { return String(format: "%.0f KB", d / 1024) }
    if d < 1073741824 { return String(format: "%.1f MB", d / 1048576) }
    if d < 1099511627776 { return String(format: "%.1f GB", d / 1073741824) }
    return String(format: "%.1f TB", d / 1099511627776)
}

func fmtSpeed(_ bytesPerSec: Double) -> String {
    if bytesPerSec <= 0 { return "— MB/s" }
    if bytesPerSec >= 1048576 { return String(format: "%.1f MB/s", bytesPerSec / 1048576) }
    return String(format: "%.0f KB/s", bytesPerSec / 1024)
}

func fmtETA(_ seconds: Double?) -> String {
    guard let s = seconds, s > 0, s.isFinite else { return "剩余 —" }
    if s < 60 { return String(format: "剩余 %.0f 秒", s) }
    if s < 3600 { return String(format: "剩余 %.0f 分钟", s / 60) }
    return String(format: "剩余 %.1f 小时", s / 3600)
}

// MARK: - 小控件

final class DropZoneView: NSView {

    var onDrop: (([URL]) -> Void)?
    private var highlight = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    private func draggedURLs(_ sender: NSDraggingInfo) -> [URL] {
        let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objs = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: opts)
        return (objs as? [URL]) ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !draggedURLs(sender).isEmpty else { return [] }
        highlight = true
        needsDisplay = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        highlight = false
        needsDisplay = true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        highlight = false
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        highlight = false
        needsDisplay = true
        let urls = draggedURLs(sender)
        guard !urls.isEmpty else { return false }
        onDrop?(urls)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        // 底色 + 45° 细条纹（照 demo dropzone 质感）
        (highlight ? Pal.accentSoft : Pal.dzBase).setFill()
        bounds.fill()
        if !highlight {
            Pal.dzStripe.setFill()
            let span = bounds.width + bounds.height
            var x = -span
            while x < span {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: x, y: 0))
                p.line(to: NSPoint(x: x + bounds.height, y: bounds.height))
                p.line(to: NSPoint(x: x + bounds.height + 12, y: bounds.height))
                p.line(to: NSPoint(x: x + 12, y: 0))
                p.close()
                p.fill()
                x += 24
            }
        }
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        border.lineWidth = 2
        border.setLineDash([6, 5], count: 2, phase: 0)
        (highlight ? Pal.accent : Pal.dzBorder).setStroke()
        border.stroke()
    }
}

final class GradientBarView: NSView {
    var fraction: Double = 0 { didSet { needsDisplay = true } }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.hex("#edf1f4").setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
        let f = CGFloat(min(max(fraction, 0), 1))
        guard f > 0.001 else { return }
        let rect = NSRect(x: 0, y: 0, width: bounds.width * f, height: bounds.height)
        if let g = NSGradient(starting: Pal.accent, ending: Pal.accentGrad2) {
            g.draw(in: NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4), angle: 0)
        }
    }
}

final class HairlineView: NSView {
    var color: NSColor = Pal.line { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }
}

final class QueueRowView: NSView {

    let nameLabel = NSTextField(labelWithString: "")
    let sizeLabel = NSTextField(labelWithString: "")
    let badgeLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        nameLabel.font = .systemFont(ofSize: 13)
        nameLabel.textColor = Pal.ink
        nameLabel.cell?.wraps = true
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 2   // 超长文件名折两行，尽量露出全名

        sizeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        sizeLabel.textColor = Pal.sub
        sizeLabel.alignment = .right
        sizeLabel.maximumNumberOfLines = 1

        badgeLabel.font = .systemFont(ofSize: 11, weight: .medium)
        badgeLabel.alignment = .center
        badgeLabel.maximumNumberOfLines = 1
        badgeLabel.wantsLayer = true
        badgeLabel.layer?.cornerRadius = 6
        badgeLabel.layer?.masksToBounds = true

        for v in [nameLabel, sizeLabel, badgeLabel] {
            addSubview(v)
            v.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    func configure(_ item: QueueItem) {
        nameLabel.stringValue = item.note.isEmpty ? item.relativePath
            : item.relativePath + " · " + item.note
        nameLabel.toolTip = item.url.path   // 悬停显示完整路径，长文件名不用猜
        sizeLabel.stringValue = fmtBytes(item.size)
        let text: String, bg: NSColor, fg: NSColor
        switch item.state {
        case .waiting: (text, bg, fg) = ("待复制", Pal.waitBg, Pal.sub)
        case .running: (text, bg, fg) = ("复制中", Pal.runBg, Pal.runFg)
        case .done: (text, bg, fg) = ("已完成", Pal.doneBg, Pal.ok)
        case .skipped: (text, bg, fg) = ("已跳过", Pal.skipBg, Pal.skipGray)
        case .failed: (text, bg, fg) = ("失败", Pal.failBg, Pal.danger)
        }
        badgeLabel.stringValue = text
        badgeLabel.textColor = fg
        badgeLabel.backgroundColor = bg
        badgeLabel.drawsBackground = true
        needsDisplay = true
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        Pal.hairline.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }

    override func layout() {
        super.layout()
        let h: CGFloat = 32
        let y = (bounds.height - h) / 2
        let sizeW: CGFloat = 86
        let badgeW: CGFloat = 74
        let gap: CGFloat = 8
        let badgeX = bounds.width - badgeW - 14
        let sizeX = badgeX - gap - sizeW
        let nameX: CGFloat = 14
        let nameW = max(sizeX - gap - nameX, 40)
        nameLabel.frame = NSRect(x: nameX, y: y, width: nameW, height: h)
        sizeLabel.frame = NSRect(x: sizeX, y: y, width: sizeW, height: h)
        badgeLabel.frame = NSRect(x: badgeX, y: y + 1, width: badgeW, height: h - 2)
    }
}

// MARK: - 主视图

final class ContentView: NSView {

    private static let defaultsKey = "LastTargetFolderPath"

    /// 首次启动的默认目标：自动挑一个外接 NTFS 卷；没有就落到桌面
    private static var defaultTarget: URL {
        if let v = VolumeLocator.preferredExternalVolume() { return v }
        return URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Desktop")
    }

    private enum MountState { case missing, readOnly, readWrite }

    // 状态
    private var items: [QueueItem] = []
    private var rowViews: [QueueRowView] = []
    private var engine: CopyEngine?
    private var running = false
    private var ranOnce = false
    private var expanding = false
    private var lastFailListText = ""
    private var targetURL: URL
    private var pollTimer: Timer?

    // UI 引用
    private var bodyStack: NSStackView!
    private var actionsStack: NSStackView!
    private var mainH: NSStackView!
    private var targetBar: NSView!
    private var optsH: NSStackView!
    private var promiseLabel: NSTextField!
    private var mountBar: NSView!
    private var ledOuter: NSView!
    private var ledDot: NSView!
    private var mountInfo: NSTextField!
    private var mountButton: NSButton!
    private var dropZone: DropZoneView!
    private var countLabel: NSTextField!
    private var skipRadio: NSButton!
    private var renameRadio: NSButton!
    private var listStack: NSStackView!
    private var emptyLabel: NSTextField!
    private var tpathLabel: NSTextField!
    private var tmetaLabel: NSTextField!
    private var tdiskLabel: NSTextField!
    private var dirLabel: NSTextField!
    private var deepVerifyCheck: NSButton!
    private var roTip: NSView!
    private var problemBar: NSView!
    private var problemText: NSTextField!
    private var busyLabel: NSTextField!
    private var progressSection: NSView!
    private var pfileLabel: NSTextField!
    private var ppctLabel: NSTextField!
    private var fillView: GradientBarView!
    private var pspeedLabel: NSTextField!
    private var petaLabel: NSTextField!
    private var report: NSView!
    private var rOkPill: NSTextField!
    private var rSkipPill: NSTextField!
    private var rFailPill: NSTextField!
    private var rNoteLabel: NSTextField!
    private var rFailList: NSTextField!
    private var copyFailButton: NSButton!
    private var copyOpenBtn: NSButton!
    private var startButton: NSButton!
    private var cancelButton: NSButton!

    // MARK: 初始化

    override init(frame frameRect: NSRect) {
        let saved = UserDefaults.standard.string(forKey: Self.defaultsKey)
        targetURL = URL(fileURLWithPath: saved ?? Self.defaultTarget.path)
        super.init(frame: frameRect)
        Log.startSession()
        Log.write("ContentView 初始化，目标=\(targetURL.path)")
        buildUI()
        refreshMountAndTarget()
        renderQueue()
        updateStartButton()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshMountAndTarget()
        }
        // 启动即自检常用文件夹权限：没有权限时立刻说清楚，而不是等用户拖文件后发现没反应
        checkFolderAccessAtLaunch()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) 未实现") }

    // MARK: UI 构件助手

    private func label(_ text: String, color: NSColor, font: NSFont,
                       align: NSTextAlignment = .left) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.textColor = color
        l.font = font
        l.alignment = align
        l.cell?.wraps = false
        return l
    }

    private func button(title: String, bg: NSColor, fg: NSColor, border: NSColor? = nil,
                        font: NSFont, radius: CGFloat) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.backgroundColor = bg.cgColor
        b.layer?.cornerRadius = radius
        b.focusRingType = .none
        if let bd = border {
            b.layer?.borderWidth = 1
            b.layer?.borderColor = bd.cgColor
        }
        setButtonTitle(b, title, fg: fg, font: font)
        b.cell?.alignment = .center
        return b
    }

    private func setButtonTitle(_ b: NSButton, _ title: String, fg: NSColor, font: NSFont) {
        b.attributedTitle = NSAttributedString(
            string: title, attributes: [.font: font, .foregroundColor: fg])
    }

    private func roundedBox(bg: NSColor, border: NSColor, radius: CGFloat) -> NSView {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = bg.cgColor
        v.layer?.borderColor = border.cgColor
        v.layer?.borderWidth = 1
        v.layer?.cornerRadius = radius
        return v
    }

    private func pin(_ child: NSView, in parent: NSView,
                     top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        child.translatesAutoresizingMaskIntoConstraints = false
        parent.addSubview(child)
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: parent.topAnchor, constant: top),
            child.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: leading),
            child.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -bottom),
            child.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -trailing)
        ])
    }

    // MARK: UI 构建

    private func buildUI() {
        // ---- 挂载状态条 ----
        mountBar = roundedBox(bg: Pal.warnBg, border: Pal.warnBorder, radius: 10)
        ledOuter = NSView()
        ledOuter.wantsLayer = true
        ledOuter.layer?.cornerRadius = 7.5
        ledDot = NSView()
        ledDot.wantsLayer = true
        ledDot.layer?.cornerRadius = 4.5
        ledDot.translatesAutoresizingMaskIntoConstraints = false
        ledOuter.addSubview(ledDot)
        NSLayoutConstraint.activate([
            ledDot.widthAnchor.constraint(equalToConstant: 9),
            ledDot.heightAnchor.constraint(equalToConstant: 9),
            ledDot.centerXAnchor.constraint(equalTo: ledOuter.centerXAnchor),
            ledDot.centerYAnchor.constraint(equalTo: ledOuter.centerYAnchor),
            ledOuter.widthAnchor.constraint(equalToConstant: 15),
            ledOuter.heightAnchor.constraint(equalToConstant: 15)
        ])
        mountInfo = NSTextField(labelWithString: "")
        mountInfo.cell?.wraps = false
        mountButton = button(title: "以读写模式重新挂载", bg: .white, fg: Pal.accentDeep,
                             border: Pal.accentDeep, font: .systemFont(ofSize: 12), radius: 8)
        mountButton.target = self
        mountButton.action = #selector(remountAction)
        mountButton.heightAnchor.constraint(equalToConstant: 26).isActive = true
        let mountH = NSStackView(views: [ledOuter, mountInfo, mountButton])
        mountH.orientation = .horizontal
        mountH.spacing = 10
        mountH.alignment = .centerY
        mountInfo.setContentHuggingPriority(.init(1), for: .horizontal)
        pin(mountH, in: mountBar, top: 10, leading: 14, bottom: 10, trailing: 14)

        // ---- 拖拽区 ----
        dropZone = DropZoneView(frame: .zero)
        dropZone.onDrop = { [weak self] urls in self?.ingest(urls: urls) }
        let dzIcon = label("📥", color: Pal.sub, font: .systemFont(ofSize: 40))
        dzIcon.alignment = .center
        let dzTitle = label("将文件 / 文件夹拖到这里", color: Pal.ink,
                            font: .systemFont(ofSize: 13, weight: .semibold))
        let dzHint = label("支持多选，文件夹自动展开子项", color: Pal.hint,
                           font: .systemFont(ofSize: 12))
        let dzOr = label("或", color: Pal.sub, font: .systemFont(ofSize: 12))
        let dzPick = button(title: "点此选择文件…", bg: .clear, fg: Pal.accentDeep,
                            font: .systemFont(ofSize: 12), radius: 4)
        dzPick.target = self
        dzPick.action = #selector(pickFilesAction)
        let dzPickRow = NSStackView(views: [dzOr, dzPick])
        dzPickRow.orientation = .horizontal
        dzPickRow.spacing = 4
        let dzV = NSStackView(views: [dzIcon, dzTitle, dzHint, dzPickRow])
        dzV.orientation = .vertical
        dzV.spacing = 8
        dzV.alignment = .centerX
        pin(dzV, in: dropZone, top: 0, leading: 8, bottom: 0, trailing: 8)
        dropZone.widthAnchor.constraint(equalToConstant: 300).isActive = true
        dropZone.heightAnchor.constraint(greaterThanOrEqualToConstant: 260).isActive = true

        // ---- 待复制清单（手工布局：头部 + 分隔线 + 滚动列表）----
        let queueBox = roundedBox(bg: Pal.panel, border: Pal.line, radius: 12)
        let qTitle = label("待复制清单", color: Pal.ink,
                           font: .systemFont(ofSize: 12, weight: .semibold))
        countLabel = label("0 项", color: Pal.sub, font: .systemFont(ofSize: 12))
        skipRadio = NSButton(radioButtonWithTitle: "同名跳过", target: self,
                             action: #selector(conflictChanged))
        renameRadio = NSButton(radioButtonWithTitle: "同名自动改名", target: self,
                               action: #selector(conflictChanged))
        skipRadio.font = .systemFont(ofSize: 12)
        renameRadio.font = .systemFont(ofSize: 12)
        skipRadio.state = .on
        let headH = NSStackView(views: [qTitle, countLabel, skipRadio!, renameRadio!])
        headH.orientation = .horizontal
        headH.spacing = 8
        headH.alignment = .centerY
        let headSpacer = NSView()
        headH.insertArrangedSubview(headSpacer, at: 2)
        headSpacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let headLine = HairlineView()
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        listStack = NSStackView()
        listStack.orientation = .vertical
        listStack.spacing = 0
        scroll.documentView = listStack
        listStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            listStack.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            listStack.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            listStack.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            listStack.bottomAnchor.constraint(equalTo: scroll.contentView.bottomAnchor),
            listStack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor)
        ])
        headH.translatesAutoresizingMaskIntoConstraints = false
        headLine.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        queueBox.addSubview(headH)
        queueBox.addSubview(headLine)
        queueBox.addSubview(scroll)
        NSLayoutConstraint.activate([
            headH.topAnchor.constraint(equalTo: queueBox.topAnchor, constant: 9),
            headH.leadingAnchor.constraint(equalTo: queueBox.leadingAnchor, constant: 14),
            headH.trailingAnchor.constraint(equalTo: queueBox.trailingAnchor, constant: -14),
            headH.heightAnchor.constraint(equalToConstant: 18),
            headLine.topAnchor.constraint(equalTo: headH.bottomAnchor, constant: 9),
            headLine.leadingAnchor.constraint(equalTo: queueBox.leadingAnchor),
            headLine.trailingAnchor.constraint(equalTo: queueBox.trailingAnchor),
            headLine.heightAnchor.constraint(equalToConstant: 1),
            scroll.topAnchor.constraint(equalTo: headLine.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: queueBox.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: queueBox.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: queueBox.bottomAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 220)
        ])
        emptyLabel = label("清单为空 —— 从左侧拖入或添加文件", color: Pal.empty,
                           font: .systemFont(ofSize: 13))
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        queueBox.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: queueBox.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor)
        ])

        // 清单区必须吃掉剩余宽度：低 hugging 让 NSStackView 把多余空间分给它，
        // 高 compression resistance 保证窗口变窄时也不被压到看不见文件名。
        dropZone.setContentHuggingPriority(.required, for: .horizontal)
        queueBox.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)
        queueBox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        mainH = NSStackView(views: [dropZone, queueBox])
        mainH.orientation = .horizontal
        mainH.spacing = 16
        mainH.alignment = .top
        mainH.distribution = .fill

        // ---- 目标文件夹 ----
        targetBar = roundedBox(bg: Pal.panel, border: Pal.line, radius: 12)
        tdiskLabel = label("💽", color: Pal.ink, font: .systemFont(ofSize: 18))
        tdiskLabel.alignment = .center
        tdiskLabel.wantsLayer = true
        tdiskLabel.layer?.backgroundColor = Pal.accentSoft.cgColor
        tdiskLabel.layer?.cornerRadius = 9
        tdiskLabel.widthAnchor.constraint(equalToConstant: 34).isActive = true
        tdiskLabel.heightAnchor.constraint(equalToConstant: 34).isActive = true
        tpathLabel = label("请选择目标文件夹", color: Pal.ink,
                           font: .systemFont(ofSize: 13, weight: .semibold))
        tpathLabel.lineBreakMode = .byTruncatingMiddle
        tmetaLabel = label("目标位置", color: Pal.sub, font: .systemFont(ofSize: 11))
        let tPathV = NSStackView(views: [tpathLabel, tmetaLabel])
        tPathV.orientation = .vertical
        tPathV.spacing = 2
        tPathV.alignment = .leading
        let chooseBtn = button(title: "选择目标文件夹…", bg: Pal.ghostBg, fg: Pal.ink,
                               font: .systemFont(ofSize: 13), radius: 9)
        chooseBtn.target = self
        chooseBtn.action = #selector(chooseTargetAction)
        chooseBtn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let finderBtn = button(title: "在 Finder 打开", bg: Pal.ghostBg, fg: Pal.ink,
                               font: .systemFont(ofSize: 13), radius: 9)
        finderBtn.target = self
        finderBtn.action = #selector(openInFinderAction)
        finderBtn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        // 先拷后开：FUSE-T 的 NFS 后端不支持 F_RDADVISE，媒体文件在硬盘上直接双击会卡死，
        // 这个按钮把选中项拷到本机临时目录再打开，绕开该限制。
        copyOpenBtn = button(title: "拷到本机并打开", bg: Pal.accentSoft, fg: Pal.accentDeep,
                             border: Pal.accentBorder, font: .systemFont(ofSize: 13), radius: 9)
        copyOpenBtn.target = self
        copyOpenBtn.action = #selector(copyToLocalAndOpenAction)
        copyOpenBtn.heightAnchor.constraint(equalToConstant: 30).isActive = true
        copyOpenBtn.toolTip = "把清单里选中的硬盘文件复制到本机后打开（视频/文档在硬盘上直接双击可能打不开）"
        let targetH = NSStackView(views: [tdiskLabel, tPathV, copyOpenBtn, chooseBtn, finderBtn])
        targetH.orientation = .horizontal
        targetH.spacing = 10
        targetH.alignment = .centerY
        tPathV.setContentHuggingPriority(.init(1), for: .horizontal)
        pin(targetH, in: targetBar, top: 12, leading: 14, bottom: 12, trailing: 14)

        // ---- 选项行 ----
        let dirTitle = label("复制方向", color: Pal.ink, font: .systemFont(ofSize: 12))
        dirLabel = label("Mac → 移动硬盘", color: Pal.accentDeep,
                         font: .systemFont(ofSize: 13, weight: .semibold))
        deepVerifyCheck = NSButton(checkboxWithTitle: "复制完成后逐字节深度校验（SHA-256，较慢）",
                                   target: nil, action: nil)
        deepVerifyCheck.font = .systemFont(ofSize: 12)
        optsH = NSStackView(views: [dirTitle, dirLabel, deepVerifyCheck])
        optsH.orientation = .horizontal
        optsH.spacing = 18
        optsH.alignment = .centerY

        // ---- 只读提示 ----
        let roText = NSTextField(wrappingLabelWithString:
            "⚠️ 目标硬盘当前为只读：可先把文件复制到 Mac（方向反过来），或点上方\"以读写模式重新挂载\"后再写入硬盘。")
        roText.font = .systemFont(ofSize: 12)
        roText.textColor = Pal.warn
        roTip = roundedBox(bg: Pal.warnBg, border: Pal.warnBorder, radius: 10)
        pin(roText, in: roTip, top: 10, leading: 14, bottom: 10, trailing: 14)

        // ---- 问题提示条（读取失败 / 部分跳过 / 展开中）----
        problemBar = roundedBox(bg: Pal.failBg, border: Pal.cancelBorder, radius: 10)
        problemText = NSTextField(wrappingLabelWithString: "")
        problemText.font = .systemFont(ofSize: 12)
        problemText.textColor = Pal.danger
        problemText.maximumNumberOfLines = 6
        let dismissProblem = button(title: "关闭", bg: .white, fg: Pal.danger,
                                    border: Pal.cancelBorder, font: .systemFont(ofSize: 12), radius: 7)
        dismissProblem.target = self
        dismissProblem.action = #selector(dismissProblemAction)
        dismissProblem.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let privacyBtn = button(title: "打开隐私设置", bg: .white, fg: Pal.accentDeep,
                                border: Pal.accentBorder, font: .systemFont(ofSize: 12), radius: 7)
        privacyBtn.target = self
        privacyBtn.action = #selector(openPrivacySettingsAction)
        privacyBtn.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let diagBtn = button(title: "环境自检", bg: .white, fg: Pal.sub,
                             border: Pal.line, font: .systemFont(ofSize: 12), radius: 7)
        diagBtn.target = self
        diagBtn.action = #selector(diagnosticsAction)
        diagBtn.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let problemRow = NSStackView(views: [problemText, privacyBtn, diagBtn, dismissProblem])
        problemRow.orientation = .horizontal
        problemRow.spacing = 8
        problemRow.alignment = .top
        problemText.setContentHuggingPriority(.init(1), for: .horizontal)
        pin(problemRow, in: problemBar, top: 10, leading: 14, bottom: 10, trailing: 14)
        busyLabel = label("", color: Pal.accentDeep, font: .systemFont(ofSize: 12))
        busyLabel.isHidden = true

        // ---- 进度 ----
        pfileLabel = label("—", color: Pal.sub, font: .systemFont(ofSize: 12))
        pfileLabel.lineBreakMode = .byTruncatingMiddle
        ppctLabel = label("0%", color: Pal.sub, font: .systemFont(ofSize: 12))
        let pTopH = NSStackView(views: [pfileLabel, ppctLabel])
        pTopH.orientation = .horizontal
        pfileLabel.setContentHuggingPriority(.init(1), for: .horizontal)
        fillView = GradientBarView()
        fillView.heightAnchor.constraint(equalToConstant: 8).isActive = true
        pspeedLabel = label("— MB/s", color: Pal.sub, font: .systemFont(ofSize: 12))
        petaLabel = label("剩余 —", color: Pal.sub, font: .systemFont(ofSize: 12))
        let pBottomH = NSStackView(views: [pspeedLabel, petaLabel])
        pBottomH.orientation = .horizontal
        let pV = NSStackView(views: [pTopH, fillView, pBottomH])
        pV.orientation = .vertical
        pV.spacing = 6
        progressSection = pV

        // ---- 完成报告 ----
        let rTitle = label("✅ 复制完成", color: Pal.ok,
                           font: .systemFont(ofSize: 13, weight: .semibold))
        rOkPill = NSTextField(labelWithString: "成功 0")
        rSkipPill = NSTextField(labelWithString: "跳过 0")
        rFailPill = NSTextField(labelWithString: "失败 0")
        for (p, c) in [(rOkPill!, Pal.ok), (rSkipPill!, Pal.skipGray), (rFailPill!, Pal.danger)] {
            p.font = .systemFont(ofSize: 13)
            p.textColor = c
            p.wantsLayer = true
            p.layer?.backgroundColor = NSColor.white.cgColor
            p.layer?.borderColor = Pal.line.cgColor
            p.layer?.borderWidth = 1
            p.layer?.cornerRadius = 7
            p.alignment = .center
            p.widthAnchor.constraint(greaterThanOrEqualToConstant: 64).isActive = true
        }
        let rNumsH = NSStackView(views: [rOkPill!, rSkipPill!, rFailPill!])
        rNumsH.orientation = .horizontal
        rNumsH.spacing = 14
        rNoteLabel = NSTextField(wrappingLabelWithString: "所有文件字节数已校验一致")
        rNoteLabel.font = .systemFont(ofSize: 12)
        rNoteLabel.textColor = Pal.sub
        rFailList = NSTextField(wrappingLabelWithString: "")
        rFailList.font = .systemFont(ofSize: 12)
        rFailList.textColor = Pal.danger
        rFailList.isSelectable = true
        copyFailButton = button(title: "复制失败清单", bg: .white, fg: Pal.danger,
                                border: Pal.cancelBorder, font: .systemFont(ofSize: 12), radius: 8)
        copyFailButton.target = self
        copyFailButton.action = #selector(copyFailListAction)
        copyFailButton.heightAnchor.constraint(equalToConstant: 26).isActive = true
        let rV = NSStackView(views: [rTitle, rNumsH, rNoteLabel])
        rV.orientation = .vertical
        rV.spacing = 8
        rV.translatesAutoresizingMaskIntoConstraints = false
        report = roundedBox(bg: Pal.reportBg, border: Pal.reportBorder, radius: 12)
        report.addSubview(rV)
        rFailList.translatesAutoresizingMaskIntoConstraints = false
        report.addSubview(rFailList)
        copyFailButton.translatesAutoresizingMaskIntoConstraints = false
        report.addSubview(copyFailButton)
        NSLayoutConstraint.activate([
            rV.topAnchor.constraint(equalTo: report.topAnchor, constant: 14),
            rV.leadingAnchor.constraint(equalTo: report.leadingAnchor, constant: 16),
            rV.trailingAnchor.constraint(equalTo: report.trailingAnchor, constant: -16),
            rFailList.topAnchor.constraint(equalTo: rV.bottomAnchor, constant: 6),
            rFailList.leadingAnchor.constraint(equalTo: rV.leadingAnchor),
            rFailList.trailingAnchor.constraint(equalTo: rV.trailingAnchor),
            copyFailButton.topAnchor.constraint(equalTo: rFailList.bottomAnchor, constant: 6),
            copyFailButton.leadingAnchor.constraint(equalTo: rV.leadingAnchor),
            copyFailButton.bottomAnchor.constraint(lessThanOrEqualTo: report.bottomAnchor,
                                                   constant: -10)
        ])

        // ---- 动作区 ----
        startButton = button(title: "开始安全复制", bg: Pal.accent, fg: .white,
                             font: .systemFont(ofSize: 15, weight: .semibold), radius: 11)
        startButton.target = self
        startButton.action = #selector(startCopyAction)
        startButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        startButton.layer?.shadowColor = Pal.accent.cgColor
        startButton.layer?.shadowOpacity = 0.35
        startButton.layer?.shadowRadius = 7
        startButton.layer?.shadowOffset = CGSize(width: 0, height: 2)
        startButton.setContentHuggingPriority(.init(1), for: .horizontal)
        cancelButton = button(title: "取消", bg: Pal.cancelBg, fg: Pal.danger,
                              border: Pal.cancelBorder, font: .systemFont(ofSize: 13), radius: 9)
        cancelButton.target = self
        cancelButton.action = #selector(cancelCopyAction)
        cancelButton.heightAnchor.constraint(equalToConstant: 34).isActive = true
        actionsStack = NSStackView(views: [startButton!, cancelButton!])
        actionsStack.orientation = .horizontal
        actionsStack.spacing = 12
        actionsStack.alignment = .centerY

        // ---- 常驻承诺 ----
        promiseLabel = NSTextField(wrappingLabelWithString: "")
        let pm = NSMutableAttributedString(
            string: "🛡  ",
            attributes: [.font: NSFont.systemFont(ofSize: 12),
                         .foregroundColor: Pal.accentDeep])
        pm.append(NSAttributedString(string: "本工具", attributes: promiseAttrs()))
        pm.append(NSAttributedString(string: "绝不覆盖", attributes: promiseAttrs(bold: true)))
        pm.append(NSAttributedString(string: " · ", attributes: promiseAttrs()))
        pm.append(NSAttributedString(string: "绝不删除", attributes: promiseAttrs(bold: true)))
        pm.append(NSAttributedString(
            string: "你的任何文件 · 同名文件自动跳过 · 复制完成即校验",
            attributes: promiseAttrs()))
        promiseLabel.attributedStringValue = pm
        promiseLabel.alignment = .center

        // ---- 组装 ----
        bodyStack = NSStackView(views: [mountBar!, busyLabel!, mainH, targetBar!, optsH,
                                        roTip!, problemBar!, progressSection!, report!,
                                        actionsStack!, promiseLabel!])
        bodyStack.orientation = .vertical
        bodyStack.alignment = .leading
        bodyStack.spacing = 16
        bodyStack.setCustomSpacing(14, after: targetBar!)
        bodyStack.setCustomSpacing(14, after: optsH!)
        bodyStack.setCustomSpacing(18, after: report!)
        // 整行组件横向铺满
        for v in [mountBar!, mainH, targetBar!, optsH!, roTip!, problemBar!, progressSection!,
                  report!, actionsStack!, promiseLabel!] as [NSView] {
            v.leadingAnchor.constraint(equalTo: bodyStack.leadingAnchor).isActive = true
            v.trailingAnchor.constraint(equalTo: bodyStack.trailingAnchor).isActive = true
        }
        busyLabel.leadingAnchor.constraint(equalTo: bodyStack.leadingAnchor, constant: 4).isActive = true
        pin(bodyStack, in: self, top: 20, leading: 24, bottom: 24, trailing: 24)

        // 初始隐藏
        setSection(roTip, visible: false)
        setSection(problemBar, visible: false)
        setSection(progressSection, visible: false)
        setSection(report, visible: false)
        setStackVisibility(cancelButton, in: actionsStack, visible: false)
    }

    private func promiseAttrs(bold: Bool = false) -> [NSAttributedString.Key: Any] {
        [.font: NSFont.systemFont(ofSize: 12, weight: bold ? .semibold : .regular),
         .foregroundColor: Pal.sub]
    }

    private var bodyOrder: [NSView] {
        [mountBar!, busyLabel!, mainH!, targetBar!, optsH!, roTip!, problemBar!,
         progressSection!, report!, actionsStack!, promiseLabel!]
    }

    /// 显隐切换：NSStackView 用「增删 arranged 子视图 + 顺序表回插」实现折叠
    private func setArranged(_ v: NSView, in stack: NSStackView,
                             visible: Bool, order: [NSView]) {
        let isArranged = stack.arrangedSubviews.contains(v)
        if visible {
            v.isHidden = false
            if !isArranged {
                var anchor: NSView? = nil
                if let idx = order.firstIndex(of: v) {
                    for j in (idx + 1)..<order.count
                    where stack.arrangedSubviews.contains(order[j]) {
                        anchor = order[j]
                        break
                    }
                }
                if let a = anchor, let pos = stack.arrangedSubviews.firstIndex(of: a) {
                    stack.insertArrangedSubview(v, at: pos)
                } else {
                    stack.addArrangedSubview(v)
                }
            }
        } else {
            v.isHidden = true
            if isArranged { stack.removeArrangedSubview(v) }
        }
    }

    private func setSection(_ v: NSView, visible: Bool) {
        setArranged(v, in: bodyStack, visible: visible, order: bodyOrder)
    }

    private func setStackVisibility(_ v: NSView, in stack: NSStackView, visible: Bool) {
        setArranged(v, in: stack, visible: visible, order: [startButton!, cancelButton!])
    }

    // MARK: - 队列渲染

    private func renderQueue() {
        for v in rowViews { v.removeFromSuperview() }
        rowViews.removeAll()
        for item in items {
            let rv = QueueRowView()
            rv.configure(item)
            rv.translatesAutoresizingMaskIntoConstraints = false
            listStack.addArrangedSubview(rv)
            rv.heightAnchor.constraint(equalToConstant: 44).isActive = true
            rv.leadingAnchor.constraint(equalTo: listStack.leadingAnchor).isActive = true
            rv.trailingAnchor.constraint(equalTo: listStack.trailingAnchor).isActive = true
            rowViews.append(rv)
        }
        countLabel.stringValue = "\(items.count) 项"
        emptyLabel.isHidden = !items.isEmpty
        updateStartButton()
    }

    private func updateRow(_ i: Int) {
        guard rowViews.indices.contains(i) else { return }
        rowViews[i].configure(items[i])
    }

    // MARK: - 拖入 / 选择文件（F1）

    private func ingest(urls: [URL]) {
        guard !running, !expanding else { NSSound.beep(); return }
        expanding = true
        Log.write("ingest 收到 \(urls.count) 个路径：\(urls.map { $0.path }.joined(separator: " | "))")
        setBusyHint("正在展开所选文件…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = DragExpander.expand(urls: urls) { n in
                DispatchQueue.main.async { self?.setBusyHint("正在展开…已找到 \(n) 个文件") }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.expanding = false
                self.setBusyHint(nil)
                if result.items.isEmpty {
                    // 一条都读不到：窗口内常驻提示（比弹窗更不易错过），并保留弹窗做一次强提醒
                    self.showProblem(result.problems.isEmpty
                                     ? ["所选位置上没有可复制的文件"]
                                     : result.problems)
                    Log.write("ingest 结果为空，问题：\(result.problems.joined(separator: " | "))")
                    if !result.problems.isEmpty { self.showUnreadableAlert(paths: result.problems) }
                    return
                }
                let existing = Set(self.items.map { $0.url.resolvingSymlinksInPath().path })
                var appended = false
                for it in result.items
                where !existing.contains(it.url.resolvingSymlinksInPath().path) {
                    self.items.append(it)
                    appended = true
                }
                if appended {
                    self.ranOnce = false
                    self.setSection(self.report, visible: false)
                    self.renderQueue()
                }
                // 部分成功：如实汇报跳过了什么
                if !result.problems.isEmpty {
                    self.showProblem(result.problems)
                } else if result.truncated {
                    self.showProblem(["文件数量超过上限（100000），仅加入了前 100000 个"])
                } else {
                    self.showProblem([])
                }
                Log.write("ingest 完成：新增 \(result.items.count) 项，问题 \(result.problems.count) 条")
            }
        }
    }

    // MARK: - 窗口内提示条

    private func setBusyHint(_ text: String?) {
        busyLabel.stringValue = text ?? ""
        busyLabel.isHidden = (text == nil)
    }

    private func showProblem(_ problems: [String]) {
        guard !problems.isEmpty else {
            problemBar.isHidden = true
            problemText.stringValue = ""
            return
        }
        let shown = problems.prefix(6)
        var text = shown.joined(separator: "\n")
        if problems.count > shown.count {
            text += "\n…另有 \(problems.count - shown.count) 条同类问题"
        }
        problemText.stringValue = text
        problemBar.isHidden = false
    }

    @objc private func openPrivacySettingsAction() {
        if let u = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(u)
        }
    }

    @objc private func dismissProblemAction() {
        showProblem([])
    }

    /// 环境自检：把报告放进窗口并复制到剪贴板，便于用户反馈
    @objc private func diagnosticsAction() {
        let text = Diagnostics.report(target: targetURL)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        let alert = NSAlert()
        alert.messageText = "环境自检完成（已复制到剪贴板）"
        alert.informativeText = text
        alert.addButton(withTitle: "在 Finder 中显示日志文件")
        alert.addButton(withTitle: "好")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([Log.fileURL])
        }
        Log.write("环境自检：\n" + text)
    }

    /// 一条都读不到时的一次性强提醒（配合窗口内常驻提示条）
    private func showUnreadableAlert(paths: [String]) {
        let alert = NSAlert()
        alert.messageText = "未能读取所选文件"
        let shown = paths.prefix(3).joined(separator: "\n")
        alert.informativeText = """
            \(shown)

            常见原因：
            · 系统未授权本 App 访问「桌面 / 下载 / 文稿」：系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 打开「硬盘复制助手」
            · 文件在 iCloud 云端尚未下载：在 Finder 里右键「立即下载」
            · 文件已被移动或删除

            授权后请退出 App 并重新打开，再试一次。点左下角「环境自检」可复制完整报告。
            """
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "好")
        if alert.runModal() == .alertFirstButtonReturn {
            openPrivacySettingsAction()
        }
    }

    @objc private func pickFilesAction() {
        guard !running else { NSSound.beep(); return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.message = "选择要复制的文件或文件夹"
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            ingest(urls: panel.urls)
        }
    }

    @objc private func conflictChanged() { /* 单选组状态即策略，开始时读取 */ }

    // MARK: - 目标文件夹（F2）

    @objc private func chooseTargetAction() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = targetURL
        panel.message = "选择复制目标文件夹"
        if panel.runModal() == .OK, let u = panel.url {
            targetURL = u
            UserDefaults.standard.set(u.path, forKey: Self.defaultsKey)
            refreshMountAndTarget()
        }
    }

    @objc private func openInFinderAction() {
        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
    }

    // MARK: - 先拷后开（绕过 FUSE-T 不支持 F_RDADVISE 的限制）

    /// 把清单里选中/全部条目复制到本机临时目录，然后逐个打开。
    /// 安全：只读源、只写本机临时目录，不删除任何文件。
    @objc private func copyToLocalAndOpenAction() {
        guard !running else { NSSound.beep(); return }
        guard !items.isEmpty else {
            showProblem(["清单为空：请先把硬盘里的文件拖进来，或用「选择文件」添加"])
            return
        }
        let sources = items.map { $0.url }
        let destRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("硬盘复制助手-先拷后开", isDirectory: true)
        try? FileManager.default.createDirectory(at: destRoot, withIntermediateDirectories: true)

        copyOpenBtn.isEnabled = false
        setButtonTitle(copyOpenBtn, "复制中…", fg: Pal.sub, font: .systemFont(ofSize: 13))
        setBusyHint("正在复制到本机… 0/\(sources.count)")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let fm = FileManager.default
            var opened: [URL] = []
            var failures: [String] = []
            for (i, src) in sources.enumerated() {
                let dst = destRoot.appendingPathComponent(src.lastPathComponent)
                // 同名不覆盖：存在则加时间戳后缀
                var finalDst = dst
                if fm.fileExists(atPath: dst.path) {
                    let stamp = Int(Date().timeIntervalSince1970)
                    let base = dst.deletingPathExtension().lastPathComponent
                    let ext = dst.pathExtension
                    finalDst = destRoot.appendingPathComponent(
                        ext.isEmpty ? "\(base)-\(stamp)" : "\(base)-\(stamp).\(ext)")
                }
                do {
                    try fm.copyItem(at: src, to: finalDst)
                    opened.append(finalDst)
                    Log.write("先拷后开：\(src.path) → \(finalDst.path)")
                } catch {
                    failures.append("\(src.lastPathComponent)：\(error.localizedDescription)")
                    Log.write("先拷后开失败 \(src.path)：\(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    self?.setBusyHint("正在复制到本机… \(i + 1)/\(sources.count)")
                }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.copyOpenBtn.isEnabled = true
                self.setButtonTitle(self.copyOpenBtn, "拷到本机并打开",
                                    fg: Pal.accentDeep, font: .systemFont(ofSize: 13))
                self.setBusyHint(nil)
                for u in opened { NSWorkspace.shared.open(u) }
                if !failures.isEmpty { self.showProblem(failures) }
                else if !opened.isEmpty {
                    self.showProblem([])
                    Log.write("先拷后开完成：\(opened.count) 个文件已打开，位置 \(destRoot.path)")
                }
            }
        }
    }

    // MARK: - 启动权限自检

    /// 逐个探测常用文件夹；无权限时给出窗口内提示（不阻塞、不弹窗轰炸）
    private func checkFolderAccessAtLaunch() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var denied: [String] = []
            let probes = [("桌面", "Desktop"), ("下载", "Downloads"), ("文稿", "Documents")]
            for (name, dir) in probes {
                let p = NSHomeDirectory() + "/" + dir
                guard FileManager.default.fileExists(atPath: p) else { continue }
                if !Diagnostics.canList(p) { denied.append(name) }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                Log.write("启动权限自检：被拒绝的文件夹=\(denied.isEmpty ? "无" : denied.joined(separator: ","))")
                guard !denied.isEmpty else { return }
                self.showProblem([
                    "系统未授权本 App 读取：\(denied.joined(separator: "、")) 文件夹。",
                    "请点「打开隐私设置」→ 在「完全磁盘访问权限」中打开「硬盘复制助手」的开关，然后退出并重新打开本 App。",
                ])
            }
        }
    }

    // MARK: - 挂载状态（F7）

    /// 探测「当前目标所在卷」的挂载状态；目标不在外接卷上时显示未连接。
    private func probeMount() -> MountState {
        guard targetURL.path.hasPrefix("/Volumes"),
              VolumeLocator.exists(targetURL) else { return .missing }
        return VolumeLocator.isReadOnly(targetURL) ? .readOnly : .readWrite
    }

    private func refreshMountAndTarget() {
        applyMountUI(probeMount())
        refreshTargetUI()
        updateStartButton()
    }

    private func applyMountUI(_ st: MountState) {
        switch st {
        case .missing:
            mountBar.layer?.backgroundColor = Pal.waitBg.cgColor
            mountBar.layer?.borderColor = Pal.line.cgColor
            ledOuter.layer?.backgroundColor = NSColor.clear.cgColor
            ledDot.layer?.backgroundColor = Pal.empty.cgColor
            mountInfo.attributedStringValue = mountText(" · 未连接 — 插入移动硬盘后自动检测")
            mountButton.isHidden = true
        case .readOnly:
            mountBar.layer?.backgroundColor = Pal.warnBg.cgColor
            mountBar.layer?.borderColor = Pal.warnBorder.cgColor
            ledOuter.layer?.backgroundColor = NSColor.clear.cgColor
            ledDot.layer?.backgroundColor = Pal.warnLed.cgColor
            mountInfo.attributedStringValue =
                mountText(" · 只读挂载（NTFS）— 可复制到 Mac，暂不能写入硬盘")
            mountButton.isHidden = false
        case .readWrite:
            mountBar.layer?.backgroundColor = Pal.accentSoft.cgColor
            mountBar.layer?.borderColor = Pal.accentBorder.cgColor
            ledOuter.layer?.backgroundColor =
                NSColor(srgbRed: 14 / 255, green: 159 / 255, blue: 138 / 255, alpha: 0.15).cgColor
            ledDot.layer?.backgroundColor = Pal.accent.cgColor
            mountInfo.attributedStringValue = mountText(" · 可读写挂载")
            mountButton.isHidden = true
        }
    }

    private func mountText(_ suffix: String) -> NSAttributedString {
        let name = targetURL.path.hasPrefix("/Volumes")
            ? VolumeLocator.displayName(targetURL)
            : "目标文件夹"
        let m = NSMutableAttributedString(
            string: name.removingPercentEncoding ?? name,
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                         .foregroundColor: Pal.ink])
        m.append(NSAttributedString(
            string: suffix,
            attributes: [.font: NSFont.systemFont(ofSize: 13),
                         .foregroundColor: Pal.sub]))
        return m
    }

    @objc private func remountAction() {
        let fm = FileManager.default
        var candidates: [URL] = []
        candidates.append(Bundle.main.bundleURL.deletingLastPathComponent()
            .appendingPathComponent("mount-rw.command"))
        if let exec = CommandLine.arguments.first {
            candidates.append(URL(fileURLWithPath: exec)
                .deletingLastPathComponent() // MacOS
                .deletingLastPathComponent() // Contents
                .deletingLastPathComponent() // *.app
                .deletingLastPathComponent() // app/
                .appendingPathComponent("mount-rw.command"))
        }
        for c in candidates where fm.fileExists(atPath: c.path) {
            NSWorkspace.shared.open(c)
            return
        }
        let alert = NSAlert()
        alert.messageText = "未找到 mount-rw.command"
        alert.informativeText =
            "请把「硬盘复制助手.app」放在 app/ 目录下运行（与 mount-rw.command 同级），或直接双击 app/mount-rw.command。"
        alert.runModal()
    }

    // MARK: - 目标展示 / 只读门（S6）

    private func refreshTargetUI() {
        tpathLabel.stringValue = targetURL.path
        let keys: Set<URLResourceKey> = [.isVolumeKey, .volumeNameKey,
                                         .volumeTotalCapacityKey,
                                         .volumeAvailableCapacityKey]
        if let rv = try? targetURL.resourceValues(forKeys: keys),
           rv.isVolume == true, let rawName = rv.volumeName {
            // FUSE-T 挂载点经 URL 读出的卷名带百分号编码（"WU%204T"），仅展示层解码
            let name = rawName.removingPercentEncoding ?? rawName
            let total = Int64(rv.volumeTotalCapacity ?? 0)
            let free = Int64(rv.volumeAvailableCapacity ?? 0)
            tmetaLabel.stringValue =
                "目标位置 · \(name)（\(fmtBytes(total))，剩余 \(fmtBytes(free))）"
        } else {
            tmetaLabel.stringValue = "目标位置 · Mac 本地文件夹"
        }
        let toDisk = targetURL.path.hasPrefix("/Volumes")
        dirLabel.stringValue = toDisk ? "Mac → 移动硬盘" : "移动硬盘 → Mac"
        tdiskLabel.stringValue = toDisk ? "💽" : "💻"
    }

    private var targetReadOnly: Bool {
        guard let ro = try? targetURL.resourceValues(forKeys: [.volumeIsReadOnlyKey])
            .volumeIsReadOnly else { return false }
        return ro
    }

    private var targetReachable: Bool {
        (try? targetURL.checkResourceIsReachable()) == true
    }

    private func updateStartButton() {
        var enabled = true
        var title = ranOnce ? "再次复制" : "开始安全复制"
        var blockReason: String? = nil
        if targetReachable && targetURL.path.hasPrefix("/Volumes") && targetReadOnly {
            title = "目标硬盘只读，暂不能复制"
            enabled = false
            blockReason = "目标硬盘当前是只读挂载：请点上方「以读写模式重新挂载」，或双击 app/mount-rw.command"
        }
        if items.isEmpty {
            enabled = false
            if blockReason == nil { blockReason = "清单为空：请把文件拖到左侧虚线框，或点「点此选择文件…」" }
        }
        if !targetReachable {
            enabled = false
            title = "目标文件夹不可用"
            blockReason = "目标文件夹不存在或无法访问：\(targetURL.path)。请点「选择目标文件夹…」重新指定（硬盘是否已插好？）"
        }
        if running { enabled = false; blockReason = nil }
        startButton.isEnabled = enabled
        setButtonTitle(startButton, title, fg: .white,
                       font: .systemFont(ofSize: 15, weight: .semibold))
        startButton.layer?.backgroundColor = (enabled ? Pal.accent : Pal.disabledBg).cgColor
        // 只读提示条（S6 指引）
        let showTip = targetReachable && targetURL.path.hasPrefix("/Volumes") && targetReadOnly
        if !running { setSection(roTip, visible: showTip) }
        // 按钮为什么点不了：说清楚，不静默
        if let reason = blockReason {
            if !items.isEmpty || !targetReachable { showProblem([reason]) }
        } else if !problemBar.isHidden, problemText.stringValue.contains("清单为空") {
            showProblem([])
        }
    }

    // MARK: - 复制流程（S1–S6 由 CopyEngine 落实）

    @objc private func startCopyAction() {
        guard !running, !items.isEmpty else { return }
        let fm = FileManager.default
        guard targetReachable, fm.isWritableFile(atPath: targetURL.path) else {
            NSSound.beep()
            return
        }
        for it in items { it.state = .waiting; it.note = "" }
        for i in items.indices { updateRow(i) }
        running = true
        setSection(report, visible: false)
        setSection(progressSection, visible: true)
        setButtonTitle(cancelButton, "取消", fg: Pal.danger, font: .systemFont(ofSize: 13))
        cancelButton.isEnabled = true
        setStackVisibility(cancelButton, in: actionsStack, visible: true)
        setStackVisibility(startButton, in: actionsStack, visible: false)
        pfileLabel.stringValue = "—"
        ppctLabel.stringValue = "0%"
        fillView.fraction = 0
        pspeedLabel.stringValue = "— MB/s"
        petaLabel.stringValue = "剩余 —"
        updateStartButton()

        let strategy: ConflictStrategy = (renameRadio.state == .on) ? .rename : .skip
        let deep = deepVerifyCheck.state == .on
        let eng = CopyEngine(
            items: items, target: targetURL, strategy: strategy, deepVerify: deep,
            onState: { [weak self] i, st, note in
                DispatchQueue.main.async {
                    guard let self = self, self.items.indices.contains(i) else { return }
                    self.items[i].state = st
                    self.items[i].note = note
                    self.updateRow(i)
                }
            },
            onProgress: { [weak self] p in
                DispatchQueue.main.async { self?.applyProgress(p) }
            },
            onDone: { [weak self] r in
                DispatchQueue.main.async { self?.finishRun(r) }
            })
        engine = eng
        eng.start()
    }

    private func applyProgress(_ p: RunProgress) {
        let phaseSuffix = p.phase == .verifying ? " · 深度校验中…" : ""
        pfileLabel.stringValue = "\(p.fileName)（\(p.fileIndex)/\(p.fileCount)）\(phaseSuffix)"
        let frac: Double = p.totalBytes > 0 ? Double(p.totalDone) / Double(p.totalBytes) : 0
        fillView.fraction = frac
        ppctLabel.stringValue = "\(Int(round(frac * 100)))%"
        pspeedLabel.stringValue = fmtSpeed(p.speedBytesPerSec)
        petaLabel.stringValue = fmtETA(p.etaSeconds)
    }

    @objc private func cancelCopyAction() {
        engine?.cancel()
        cancelButton.isEnabled = false
        setButtonTitle(cancelButton, "正在停止…", fg: Pal.danger, font: .systemFont(ofSize: 13))
    }

    private func finishRun(_ r: RunResult) {
        running = false
        engine = nil
        ranOnce = true
        setSection(progressSection, visible: false)
        setStackVisibility(cancelButton, in: actionsStack, visible: false)
        setStackVisibility(startButton, in: actionsStack, visible: true)
        updateStartButton()
        // 报告（F8）
        rOkPill.stringValue = "成功 \(r.okCount)"
        rSkipPill.stringValue = "跳过 \(r.skipCount)"
        rFailPill.stringValue = "失败 \(r.failCount)"
        if r.cancelled {
            rNoteLabel.stringValue = "已按你的要求停止；已完成与已跳过的文件均安全保留。"
        } else if r.deepVerifyUsed && r.okCount > 0 {
            rNoteLabel.stringValue = "所有文件 SHA-256 逐字节校验一致 ✓"
        } else if r.okCount == 0 && r.failCount > 0 {
            rNoteLabel.stringValue = "没有文件被复制，请查看失败原因"
        } else {
            rNoteLabel.stringValue = "所有文件字节数已校验一致"
        }
        if r.failures.isEmpty {
            lastFailListText = ""
            rFailList.stringValue = ""
            rFailList.isHidden = true
            copyFailButton.isHidden = true
        } else {
            lastFailListText = "失败清单：" + r.failures.joined(separator: "、")
            rFailList.stringValue = lastFailListText
            rFailList.isHidden = false
            copyFailButton.isHidden = false
            setButtonTitle(copyFailButton, "复制失败清单", fg: Pal.danger,
                           font: .systemFont(ofSize: 12))
        }
        setSection(report, visible: true)
    }

    @objc private func copyFailListAction() {
        guard !lastFailListText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lastFailListText, forType: .string)
        setButtonTitle(copyFailButton, "已复制 ✓", fg: Pal.danger,
                       font: .systemFont(ofSize: 12))
    }
}
