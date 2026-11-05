import AppKit
import SwiftUI
import Combine

final class Store: ObservableObject {
    @Published var settings: WorkSettings
    init() {
        if let data = UserDefaults.standard.data(forKey: "workSettings"),
           let saved = try? JSONDecoder().decode(WorkSettings.self, from: data), saved.valid {
            settings = saved
        } else { settings = WorkSettings() }
    }
    func save(_ value: WorkSettings) throws {
        let data = try JSONEncoder().encode(value)
        UserDefaults.standard.set(data, forKey: "workSettings")
        settings = value
    }
}

private let background = Color(red: 0.078, green: 0.098, blue: 0.082)
private let muted = Color(red: 0.70, green: 0.75, blue: 0.65)
private let gold = Color(red: 0.91, green: 0.82, blue: 0.59)

struct Dashboard: View {
    @ObservedObject var store: Store
    var configure: () -> Void
    var hide: () -> Void
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    private var payroll: Payroll { Payroll(settings: store.settings) }
    private var shift: (start: Date, end: Date) { payroll.nextShift(now) }
    private var working: Bool { now >= shift.start }
    private var day: Date { working ? shift.start : now }
    private var elapsed: Double { payroll.seconds(day, now: now) }
    private var duration: Double { let s = payroll.shift(day); return s.end.timeIntervalSince(s.start) }
    private var dateLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_CN"); f.dateFormat = "M月d日 EEEE"
        return f.string(from: now)
    }
    private var status: String { working ? "上班中" : elapsed > 0 ? "已下班" : payroll.isWorkday(now) ? "待上班" : "休息日" }
    private var countdown: String {
        let seconds = max(0, Int((working ? shift.end : shift.start).timeIntervalSince(now)))
        return String(format: "%02d : %02d : %02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
    private var daily: String {
        let list = ["准时下班", "喝杯好咖啡", "给自己一点奖励", "慢慢来，也认真做", "把小事做好", "伸个懒腰", "期待下班后的生活", "保持好心情", "吃顿喜欢的饭", "为自己鼓掌", "忙里偷个闲", "攒一点小确幸"]
        let c = Calendar.current
        let base = c.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let n = c.dateComponents([.day], from: base, to: c.startOfDay(for: now)).day ?? 0
        return "今日宜" + list[(n % list.count + list.count) % list.count]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
            HStack {
                Text("上班鼓励器").font(.system(size: 21, weight: .medium))
                Spacer()
                Button(action: hide) { Image(systemName: "minus").frame(width: 30, height: 26) }.help("收起到菜单栏")
            }
            Text(dateLabel + "  ·  " + status).font(.system(size: 13)).foregroundColor(muted).padding(.top, 15)
            Text("今日已赚").font(.system(size: 13)).foregroundColor(muted).padding(.top, 24)
            Text(String(format: "¥ %.4f", payroll.earnings(day, now: now)))
                .font(.system(size: 43, weight: .regular, design: .rounded)).monospacedDigit()
                .foregroundColor(gold).lineLimit(1).minimumScaleFactor(0.45).padding(.top, 5)
            Text(String(format: "每秒进账 ¥%.4f", payroll.rate(day))).font(.system(size: 13)).foregroundColor(muted).padding(.top, 9)
            }
            Group {
            Rectangle().fill(muted.opacity(0.2)).frame(height: 1).padding(.vertical, 21)
            Text(working ? "距离下班还有" : "距离下次上班").font(.system(size: 13)).foregroundColor(muted)
            Text(countdown).font(.system(size: 29, weight: .regular, design: .rounded)).monospacedDigit().padding(.top, 6)
            Text(String(format: "已工作 %.2f / %.2f 小时   ·   %.1f%%", elapsed / 3600, duration / 3600, min(100, elapsed / duration * 100)))
                .font(.system(size: 12)).foregroundColor(muted).padding(.top, 17)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(muted.opacity(0.2))
                    Capsule().fill(muted).frame(width: proxy.size.width * CGFloat(min(1, elapsed / duration)))
                }
            }.frame(height: 6).padding(.top, 10)
            }
            Group {
            Text(String(format: "本月累计  ¥%.2f", payroll.monthTotal(now))).font(.system(size: 20)).foregroundColor(gold).lineLimit(1).minimumScaleFactor(0.5).padding(.top, 20)
            Text("生活的底气，正在一秒一秒攒起来。").font(.system(size: 12)).foregroundColor(muted).padding(.top, 12)
            Spacer(minLength: 12)
            HStack {
                Text(Payroll.clock(store.settings.startMinute) + " — " + Payroll.clock(store.settings.endMinute) + " · 自动计薪").font(.system(size: 12)).foregroundColor(muted)
                Spacer()
                Button("设置", action: configure)
            }
            Text(daily).font(.system(size: 12)).foregroundColor(gold).padding(.top, 10)
            }
        }
        .padding(24).frame(width: 390, height: 520).background(background)
        .foregroundColor(Color(red: 0.93, green: 0.94, blue: 0.90))
        .preferredColorScheme(.dark).onReceive(timer) { now = $0 }
    }
}

struct SettingsView: View {
    @ObservedObject var store: Store
    var close: () -> Void
    @State private var salary: String
    @State private var weekdays: Set<Int>
    @State private var start: Date
    @State private var end: Date
    @State private var error = ""
    init(store: Store, close: @escaping () -> Void) {
        self.store = store; self.close = close
        let c = store.settings
        _salary = State(initialValue: String(format: "%.2f", c.salary))
        _weekdays = State(initialValue: c.weekdays)
        let cal = Calendar.current
        _start = State(initialValue: cal.date(bySettingHour: c.startMinute / 60, minute: c.startMinute % 60, second: 0, of: Date())!)
        _end = State(initialValue: cal.date(bySettingHour: c.endMinute / 60, minute: c.endMinute % 60, second: 0, of: Date())!)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("薪资与排班设置").font(.title2)
            HStack { Text("月度工资（元）"); TextField("12000", text: $salary).textFieldStyle(.roundedBorder) }
            Text("每周上班日期")
            HStack(spacing: 10) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { d in
                    Toggle(["日", "一", "二", "三", "四", "五", "六"][d - 1], isOn: Binding(get: { weekdays.contains(d) }, set: { on in if on { weekdays.insert(d) } else { weekdays.remove(d) } }))
                }
            }
            HStack {
                Button("周一至周五") { weekdays = [2, 3, 4, 5, 6] }
                Button("周一至周六") { weekdays = [2, 3, 4, 5, 6, 7] }
                Button("每天") { weekdays = Set(1...7) }
            }
            HStack {
                DatePicker("上班", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("下班", selection: $end, displayedComponents: .hourAndMinute)
            }
            Text("上下班之间连续计薪，关闭应用也不影响累计。修改设置将重算本月，不自动扣除午休或节假日。跨午夜班次归属开始日。").font(.callout).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            Text(error).font(.callout).foregroundColor(.red).frame(minHeight: 18)
            HStack {
                Spacer(); Button("取消", action: close)
                Button("保存设置") {
                    let cal = Calendar.current
                    let value = WorkSettings(salary: Double(salary) ?? 0, weekdays: weekdays, startMinute: cal.component(.hour, from: start) * 60 + cal.component(.minute, from: start), endMinute: cal.component(.hour, from: end) * 60 + cal.component(.minute, from: end))
                    guard value.valid else { error = "请填写有效工资、至少一个工作日及不同的上下班时间。"; return }
                    do { try store.save(value); close() } catch { self.error = "保存失败，请重试。" }
                }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 480).preferredColorScheme(.dark)
    }
}

final class FloatingPanel: NSPanel { override var canBecomeKey: Bool { true } }

final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = Store()
    var panel: FloatingPanel!
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 390, height: 520), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "上班鼓励器"; panel.isFloatingPanel = true; panel.level = .floating
        panel.hidesOnDeactivate = false; panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false; panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: Dashboard(store: store, configure: { [weak self] in self?.showSettings() }, hide: { [weak self] in self?.panel.orderOut(nil) }))
        if !panel.setFrameUsingName("WorkCheerPanel") {
            let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            panel.setFrameOrigin(NSPoint(x: screen.maxX - 414, y: screen.maxY - 550))
        }
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(panel.frame) }) { panel.center() }
        panel.setFrameAutosaveName("WorkCheerPanel")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "薪"
        let menu = NSMenu()
        for (title, action) in [("显示悬浮窗", #selector(showPanel)), ("薪资与排班设置", #selector(showSettings)), ("切换置顶", #selector(togglePin)), ("退出", #selector(quit))] {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu; showPanel()
    }
    @objc func showPanel() { panel.orderFrontRegardless() }
    @objc func togglePin() { panel.level = panel.level == .floating ? .normal : .floating }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func showSettings() {
        if let window = settingsWindow, window.isVisible { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 420), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "薪资与排班设置"; window.isReleasedWhenClosed = false; window.level = .floating
        window.contentView = NSHostingView(rootView: SettingsView(store: store, close: { [weak self] in self?.settingsWindow?.close() }))
        window.center(); settingsWindow = window; window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
}

@main struct WorkCheer {
    static func main() {
        if CommandLine.arguments.contains("--self-test") { Payroll.selfTest(); return }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

