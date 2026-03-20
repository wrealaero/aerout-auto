import Foundation
import AppKit

enum MouseButton: String, CaseIterable, Codable {
    case left = "Left"; case right = "Right"; case middle = "Middle"
    var cgDownType: CGEventType { switch self { case .left: return .leftMouseDown; case .right: return .rightMouseDown; case .middle: return .otherMouseDown } }
    var cgUpType:   CGEventType { switch self { case .left: return .leftMouseUp;   case .right: return .rightMouseUp;   case .middle: return .otherMouseUp   } }
    var cgButton: CGMouseButton { switch self { case .left: return .left;           case .right: return .right;          case .middle: return .center          } }
}

enum ActivationMode: String, CaseIterable, Codable {
    case toggle = "Toggle"; case hold = "Hold"
}

enum HotkeyTrigger: Codable, Equatable {
    case keyboard(keyCode: UInt16, modifiers: UInt)
    case mouseButton(number: Int)

    var label: String {
        switch self {
        case .keyboard(let kc, let mods):
            let f = NSEvent.ModifierFlags(rawValue: mods)
            var p: [String] = []
            if f.contains(.control) { p.append("^")     }
            if f.contains(.option)  { p.append("Alt")   }
            if f.contains(.shift)   { p.append("Shift") }
            if f.contains(.command) { p.append("Cmd")   }
            p.append(Self.keyName(kc))
            return p.joined(separator: "+")
        case .mouseButton(let n):
            switch n { case 2: return "Middle"; case 3: return "Side 1"; case 4: return "Side 2"; default: return "Btn\(n+1)" }
        }
    }

    static func keyName(_ code: UInt16) -> String {
        let m: [UInt16: String] = [
            122:"F1",120:"F2",99:"F3",118:"F4",96:"F5",97:"F6",98:"F7",100:"F8",
            101:"F9",109:"F10",103:"F11",111:"F12",49:"Space",36:"Enter",53:"Esc",
            123:"←",124:"→",125:"↓",126:"↑",51:"Delete",48:"Tab"
        ]
        if let n = m[code] { return n }
        let src = CGEventSource(stateID: .hidSystemState)
        let ev  = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        var len = 1; var chars = [UniChar](repeating: 0, count: 4)
        ev?.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &len, unicodeString: &chars)
        if len > 0, let s = Unicode.Scalar(chars[0]) { let c = String(s).uppercased(); if !c.isEmpty && c != "\0" { return c } }
        return "K\(code)"
    }
}

struct ClickPreset: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var cps: Double
    var duty: Double
    var button: MouseButton

    var shareCode: String { "AEROUT:\(name):\(String(format:"%.2f",cps)):\(String(format:"%.2f",duty)):\(button.rawValue)" }

    static func fromCode(_ s: String) -> ClickPreset? {
        let parts = s.trimmingCharacters(in: .whitespaces).components(separatedBy: ":")
        guard parts.count == 5, parts[0] == "AEROUT",
              let cps = Double(parts[2]), let duty = Double(parts[3]),
              let btn = MouseButton(rawValue: parts[4]) else { return nil }
        return ClickPreset(name: parts[1], cps: cps, duty: duty, button: btn)
    }
}

class AutoClicker: ObservableObject {
    static let shared = AutoClicker()

    @Published var isRunning         = false
    @Published var cps: Double       = 10.0
    @Published var duty: Double      = 50.0
    @Published var mouseBtn: MouseButton      = .left
    @Published var activationMode: ActivationMode = .toggle
    @Published var hotkey: HotkeyTrigger     = .keyboard(keyCode: 97, modifiers: 0)
    @Published var isRecording       = false
    @Published var sessionClicks     = 0
    @Published var hasAccessibility  = false
    @Published var accessibilityDenied = false
    @Published var presets: [ClickPreset] = []
    @Published var quickSlots: [UUID?]    = [nil, nil, nil, nil]

    private let clickQueue = DispatchQueue(label: "aerout.clicker", qos: .userInteractive)
    private var clickSource: DispatchSourceTimer?

    private let stateLock = NSLock()
    private var runningState = false

    private var localKey:     Any?; private var globalKey:     Any?
    private var localKeyUp:   Any?; private var globalKeyUp:   Any?
    private var localMouse:   Any?; private var globalMouse:   Any?
    private var localMouseUp: Any?; private var globalMouseUp: Any?

    private init() { loadSettings(); setupMonitors(); checkAccessibility() }
    deinit { removeMonitors() }

    func checkAccessibility() {
        DispatchQueue.main.async { self.hasAccessibility = AXIsProcessTrusted() }
    }

    func requestAccessibility() {
        guard !AXIsProcessTrusted() else { checkAccessibility(); return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        for t in [2.0, 5.0, 10.0, 20.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                self.hasAccessibility = AXIsProcessTrusted()
            }
        }
    }

    func requestInputMonitoring() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!
        NSWorkspace.shared.open(url)
    }

    private func setupMonitors() {
        removeMonitors()

        localKey = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            guard let self = self else { return ev }
            if self.isRecording {
                if ev.keyCode == 53 { DispatchQueue.main.async { self.isRecording = false } }
                else                { DispatchQueue.main.async { self.recordKey(ev) } }
                return nil
            }
            if self.matchKey(ev) { DispatchQueue.main.async { self.handlePress() }; return nil }
            return ev
        }
        globalKey = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] ev in
            guard let self = self else { return }
            if self.matchKey(ev) { DispatchQueue.main.async { self.handlePress() } }
        }
        localKeyUp = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] ev in
            guard let self = self else { return ev }
            if self.activationMode == .hold && self.matchKey(ev) {
                DispatchQueue.main.async { if self.isRunning { self.stop() } }
                return nil
            }
            return ev
        }
        globalKeyUp = NSEvent.addGlobalMonitorForEvents(matching: .keyUp) { [weak self] ev in
            guard let self = self else { return }
            if self.activationMode == .hold && self.matchKey(ev) {
                DispatchQueue.main.async { if self.isRunning { self.stop() } }
            }
        }
        localMouse = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown) { [weak self] ev in
            guard let self = self else { return ev }
            if self.isRecording { DispatchQueue.main.async { self.recordMouse(ev) }; return nil }
            if self.matchMouse(ev) { DispatchQueue.main.async { self.handlePress() }; return nil }
            return ev
        }
        globalMouse = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown) { [weak self] ev in
            guard let self = self else { return }
            if self.matchMouse(ev) { DispatchQueue.main.async { self.handlePress() } }
        }
        localMouseUp = NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { [weak self] ev in
            guard let self = self else { return ev }
            if self.activationMode == .hold && self.matchMouse(ev) {
                DispatchQueue.main.async { if self.isRunning { self.stop() } }
                return nil
            }
            return ev
        }
        globalMouseUp = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseUp) { [weak self] ev in
            guard let self = self else { return }
            if self.activationMode == .hold && self.matchMouse(ev) {
                DispatchQueue.main.async { if self.isRunning { self.stop() } }
            }
        }
    }

    private func removeMonitors() {
        [localKey,globalKey,localKeyUp,globalKeyUp,localMouse,globalMouse,localMouseUp,globalMouseUp]
            .compactMap { $0 }.forEach { NSEvent.removeMonitor($0) }
        localKey=nil; globalKey=nil; localKeyUp=nil; globalKeyUp=nil
        localMouse=nil; globalMouse=nil; localMouseUp=nil; globalMouseUp=nil
    }

    private func matchKey(_ ev: NSEvent) -> Bool {
        guard case .keyboard(let kc, let mods) = hotkey, ev.keyCode == kc else { return false }
        return ev.modifierFlags.intersection([.shift,.control,.option,.command]).rawValue == mods
    }
    private func matchMouse(_ ev: NSEvent) -> Bool {
        guard case .mouseButton(let n) = hotkey else { return false }
        return ev.buttonNumber == n
    }
    private func recordKey(_ ev: NSEvent) {
        let mods = ev.modifierFlags.intersection([.shift,.control,.option,.command])
        hotkey = .keyboard(keyCode: ev.keyCode, modifiers: mods.rawValue)
        isRecording = false; saveSettings()
    }
    private func recordMouse(_ ev: NSEvent) {
        hotkey = .mouseButton(number: ev.buttonNumber)
        isRecording = false; saveSettings()
    }

    private func handlePress() {
        switch activationMode {
        case .toggle: toggle()
        case .hold:   if !isRunning { start() }
        }
    }

    func toggle() {
        stateLock.lock()
        let shouldStop = runningState
        stateLock.unlock()
        if shouldStop { stop() } else { start() }
    }

    func start() {
        guard hasAccessibility else {

            DispatchQueue.main.async { self.checkAccessibility() }
            return
        }
        stateLock.lock()
        guard !runningState else { stateLock.unlock(); return }
        runningState = true
        stateLock.unlock()

        DispatchQueue.main.async {
            self.isRunning = true
            self.sessionClicks = 0
        }
        startTimer()
        NotificationCenter.default.post(name: .clickerStateChanged, object: nil)
    }

    func stop() {
        stateLock.lock()
        guard runningState else { stateLock.unlock(); return }
        runningState = false
        stateLock.unlock()

        clickSource?.cancel()
        clickSource = nil

        DispatchQueue.main.async { self.isRunning = false }
        NotificationCenter.default.post(name: .clickerStateChanged, object: nil)
    }

    private var snapCPS:  Double      = 10.0
    private var snapDuty: Double      = 50.0
    private var snapBtn:  MouseButton = .left
    private var snapScreenH: Double   = 900.0

    private func startTimer() {

        snapCPS     = cps
        snapDuty    = duty
        snapBtn     = mouseBtn
        snapScreenH = Double(NSScreen.main?.frame.height ?? 900.0)

        clickSource?.cancel()
        let src = DispatchSource.makeTimerSource(flags: [], queue: clickQueue)
        let intervalNs = UInt64(1_000_000_000.0 / max(snapCPS, 0.01))
        src.schedule(deadline: .now(), repeating: .nanoseconds(Int(intervalNs)), leeway: .nanoseconds(500))
        src.setEventHandler { [weak self] in self?.fire() }
        src.resume()
        clickSource = src
    }

    private func postClick(type: CGEventType, button: CGMouseButton, at pt: CGPoint) {
        let src = CGEventSource(stateID: .combinedSessionState)
        guard let ev = CGEvent(mouseEventSource: src,
                               mouseType: type,
                               mouseCursorPosition: pt,
                               mouseButton: button) else { return }
        ev.setIntegerValueField(.mouseEventDeltaX, value: 0)
        ev.setIntegerValueField(.mouseEventDeltaY, value: 0)
        ev.post(tap: .cgSessionEventTap)
    }

    private func fire() {
        stateLock.lock()
        let running = runningState
        stateLock.unlock()
        guard running else { return }

        let btn         = snapBtn
        let intervalSec = 1.0 / max(snapCPS, 0.01)
        let holdSec     = intervalSec * min(max(snapDuty, 0.01), 99.99) / 100.0
        let sh          = snapScreenH

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.stateLock.lock()
            let running = self.runningState
            self.stateLock.unlock()
            guard running else { return }

            let loc = NSEvent.mouseLocation
            let pt  = CGPoint(x: loc.x, y: CGFloat(sh) - loc.y)
            self.postClick(type: btn.cgDownType, button: btn.cgButton, at: pt)

            DispatchQueue.main.asyncAfter(deadline: .now() + holdSec) { [weak self] in
                guard let self = self else { return }
                self.stateLock.lock()
                let stillRunning = self.runningState
                self.stateLock.unlock()
                guard stillRunning else { return }

                let loc2 = NSEvent.mouseLocation
                let pt2  = CGPoint(x: loc2.x, y: CGFloat(sh) - loc2.y)
                self.postClick(type: btn.cgUpType, button: btn.cgButton, at: pt2)
                self.sessionClicks += 1
            }
        }
    }

    func saveAsPreset(name: String) { presets.append(ClickPreset(name: name, cps: cps, duty: duty, button: mouseBtn)); saveSettings() }
    func loadPreset(_ p: ClickPreset) { cps = p.cps; duty = p.duty; mouseBtn = p.button; saveSettings() }
    func deletePresets(at i: IndexSet) { presets.remove(atOffsets: i); saveSettings() }
    func renamePreset(id: UUID, to n: String) {
        if let i = presets.firstIndex(where: { $0.id == id }) { presets[i].name = n; saveSettings() }
    }
    func importPreset(from code: String) -> Bool {
        guard let p = ClickPreset.fromCode(code) else { return false }
        presets.append(p); saveSettings(); return true
    }
    func presetForSlot(_ slot: Int) -> ClickPreset? {
        guard slot < quickSlots.count, let id = quickSlots[slot] else { return nil }
        return presets.first(where: { $0.id == id })
    }
    func assignSlot(_ slot: Int, preset: ClickPreset?) { quickSlots[slot] = preset?.id; saveSettings() }

    func saveSettings() {
        let d = UserDefaults.standard
        d.set(cps, forKey: "aa_cps"); d.set(duty, forKey: "aa_duty")
        d.set(mouseBtn.rawValue, forKey: "aa_btn")
        d.set(activationMode.rawValue, forKey: "aa_mode")
        if let hd = try? JSONEncoder().encode(hotkey)     { d.set(hd, forKey: "aa_hotkey")     }
        if let pd = try? JSONEncoder().encode(presets)    { d.set(pd, forKey: "aa_presets")    }
        if let qd = try? JSONEncoder().encode(quickSlots) { d.set(qd, forKey: "aa_quickslots") }
    }

    private func loadSettings() {
        let d = UserDefaults.standard
        if let v = d.object(forKey: "aa_cps")  as? Double { cps  = v }
        if let v = d.object(forKey: "aa_duty") as? Double { duty = v }
        if let s = d.string(forKey: "aa_btn"),  let b = MouseButton(rawValue: s)    { mouseBtn       = b }
        if let s = d.string(forKey: "aa_mode"), let m = ActivationMode(rawValue: s) { activationMode = m }
        if let hd = d.data(forKey: "aa_hotkey"),     let h = try? JSONDecoder().decode(HotkeyTrigger.self, from: hd)  { hotkey     = h }
        if let pd = d.data(forKey: "aa_presets"),    let p = try? JSONDecoder().decode([ClickPreset].self, from: pd)  { presets    = p }
        if let qd = d.data(forKey: "aa_quickslots"), let q = try? JSONDecoder().decode([UUID?].self, from: qd)        { quickSlots = q }

        runningState = false
    }

    var intervalMs: Double { 1000.0 / max(cps, 0.01) }
    var holdMs: Double     { intervalMs * min(max(duty, 0.01), 99.99) / 100.0 }
}
