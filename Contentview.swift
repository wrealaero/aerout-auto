import SwiftUI
import AppKit

struct AccentTheme { let name: String; let color: Color }
let kThemes: [AccentTheme] = [
    .init(name:"Blue",   color:Color(red:0.20,green:0.53,blue:1.00)),
    .init(name:"Green",  color:Color(red:0.15,green:0.82,blue:0.37)),
    .init(name:"Red",    color:Color(red:1.00,green:0.25,blue:0.25)),
    .init(name:"Purple", color:Color(red:0.68,green:0.28,blue:1.00)),
    .init(name:"Orange", color:Color(red:1.00,green:0.57,blue:0.08)),
    .init(name:"Cyan",   color:Color(red:0.08,green:0.82,blue:0.92)),
    .init(name:"Pink",   color:Color(red:1.00,green:0.28,blue:0.65)),
    .init(name:"White",  color:.white),
]
struct BgTheme { let name: String; let color: Color }
let kBgThemes: [BgTheme] = [
    .init(name:"System",   color:Color(NSColor.windowBackgroundColor)),
    .init(name:"Midnight", color:Color(red:0.05,green:0.05,blue:0.08)),
    .init(name:"Dark",     color:Color(red:0.10,green:0.10,blue:0.12)),
    .init(name:"Navy",     color:Color(red:0.04,green:0.06,blue:0.15)),
    .init(name:"Forest",   color:Color(red:0.04,green:0.10,blue:0.06)),
    .init(name:"Slate",    color:Color(red:0.08,green:0.10,blue:0.14)),
    .init(name:"Wine",     color:Color(red:0.12,green:0.04,blue:0.07)),
    .init(name:"Charcoal", color:Color(red:0.12,green:0.12,blue:0.14)),
]

struct ContentView: View {
    @ObservedObject var clicker: AutoClicker
    @AppStorage("accentIndex") var accentIndex: Int = 0
    @AppStorage("bgIndex")     var bgIndex:     Int = 0
    @State private var tab = 0
    @State private var updateVersion: String? = nil

    var accent:  Color { kThemes[min(accentIndex,  kThemes.count  - 1)].color }
    var bgColor: Color { kBgThemes[min(bgIndex, kBgThemes.count - 1)].color }

    var body: some View {
        ZStack(alignment: .top) {
            bgColor.ignoresSafeArea()
            VStack(spacing: 0) {
                if let v = updateVersion { updateBanner(v) }
                headerBar
                Divider().opacity(0.3)
                tabBar
                Divider().opacity(0.3)
                Group {
                    switch tab {
                    case 1:  presetsTab
                    case 2:  settingsTab
                    default: mainTab
                    }
                }
            }
        }
        .frame(width: 440, height: 590)
        .onAppear { clicker.checkAccessibility() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            clicker.checkAccessibility()
        }
        .onReceive(NotificationCenter.default.publisher(for: .updateAvailable)) { n in
            updateVersion = n.object as? String
        }
    }

    func updateBanner(_ v: String) -> some View {
        HStack {
            Image(systemName: "arrow.down.circle.fill").foregroundColor(.green)
            Text("Update v\(v) available").font(.system(size: 11))
            Spacer()
            Button("Download") {
                NSWorkspace.shared.open(URL(string: "https://github.com/wrealaero/aerout-auto/releases")!)
            }.buttonStyle(.borderedProminent).tint(.green).controlSize(.mini)
            Button { updateVersion = nil } label: {
                Image(systemName: "xmark").font(.system(size: 10))
            }.buttonStyle(.plain).foregroundColor(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Color.green.opacity(0.08))
    }

    var headerBar: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(accent).frame(width: 4, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text("AEROUT AUTO")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(accent)
                Text("v1.0 Beta  •  by Aero")
                    .font(.system(size: 9)).foregroundColor(.secondary)
            }
            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(clicker.isRunning ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(clicker.isRunning ? "ACTIVE" : "IDLE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(clicker.isRunning ? .green : .secondary)
            }
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Capsule().fill((clicker.isRunning ? Color.green : Color.gray).opacity(0.09)))
            .animation(.easeInOut(duration: 0.2), value: clicker.isRunning)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(["Main","Presets","Settings"].enumerated()), id: \.0) { i, name in
                Button { withAnimation(.easeInOut(duration: 0.15)) { tab = i } } label: {
                    VStack(spacing: 0) {
                        Text(name)
                            .font(.system(size: 12, weight: tab == i ? .semibold : .regular))
                            .foregroundColor(tab == i ? accent : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                        Rectangle().fill(accent).frame(height: 2).opacity(tab == i ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension ContentView {
    var mainTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                if !clicker.hasAccessibility { accessBanner }
                speedCard
                controlsCard
                quickPresetsCard
                bigButton
                if clicker.sessionClicks > 0 || clicker.isRunning { statsRow }
            }
            .padding(14)
            .animation(.easeInOut(duration: 0.2), value: clicker.isRunning)
        }
    }

    var accessBanner: some View {
        VStack(spacing: 6) {
            Button { clicker.requestAccessibility() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "cursorarrow.click").font(.system(size: 15)).foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("1. Accessibility — Required to click").font(.system(size: 11, weight: .semibold))
                        Text("Tap to open System Preferences and grant access").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle").foregroundColor(.orange).font(.system(size: 13))
                }
                .padding(10)
                .background(Color.orange.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
                .cornerRadius(8)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)

            Button { clicker.requestInputMonitoring() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "keyboard").font(.system(size: 15)).foregroundColor(.yellow)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("2. Input Monitoring — Required for hotkey").font(.system(size: 11, weight: .semibold))
                        Text("Without this the hotkey won't work in-game").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle").foregroundColor(.yellow).font(.system(size: 13))
                }
                .padding(10)
                .background(Color.yellow.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.25), lineWidth: 1))
                .cornerRadius(8)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }

    var speedCard: some View {
        card(title: "SPEED", icon: "speedometer") {
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 0) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Clicks Per Second").font(.system(size: 10)).foregroundColor(.secondary)
                        DecimalField(value: $clicker.cps, suffix: "CPS", accent: accent, lo: 0.01, hi: 1000)
                    }
                    Spacer()

                    Divider().frame(height: 52).padding(.horizontal, 8)
                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Click Duty").font(.system(size: 10)).foregroundColor(.secondary)
                        DecimalField(value: $clicker.duty, suffix: "%", accent: accent, lo: 0.01, hi: 99.99)
                    }
                }

                HStack {
                    HStack(spacing: 3) {
                        Text("Interval:").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(String(format: "%.2f ms", clicker.intervalMs))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(accent)
                    }
                    Spacer()
                    HStack(spacing: 3) {
                        Text("Hold:").font(.system(size: 10)).foregroundColor(.secondary)
                        Text(String(format: "%.2f ms", clicker.holdMs))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(accent)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    var controlsCard: some View {
        card(title: "CONTROLS", icon: "keyboard") {
            VStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Toggle Hotkey").font(.system(size: 10)).foregroundColor(.secondary)
                    Button {
                        clicker.isRecording.toggle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: clicker.isRecording ? "keyboard.badge.eye" : "keyboard")
                                .font(.system(size: 14))
                                .foregroundColor(clicker.isRecording ? .orange : accent)
                            Text(clicker.isRecording ? "Press any key, side button, or Esc…" : clicker.hotkey.label)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(clicker.isRecording ? .orange : accent)
                            Spacer()
                            if !clicker.isRecording {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill((clicker.isRecording ? Color.orange : accent).opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke((clicker.isRecording ? Color.orange : accent).opacity(0.35), lineWidth: 1.5)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .animation(.easeInOut(duration: 0.15), value: clicker.isRecording)
                    Text("Supports any key combo (Shift+Q, Ctrl+F6…) and mouse side buttons")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }

                Divider().opacity(0.3)

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mouse Button").font(.system(size: 10)).foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            ForEach(MouseButton.allCases, id: \.self) { b in
                                PillToggle(label: b.rawValue, selected: clicker.mouseBtn == b, accent: accent) {
                                    clicker.mouseBtn = b
                                }
                            }
                        }
                    }
                    Divider().frame(height: 38)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mode").font(.system(size: 10)).foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            ForEach(ActivationMode.allCases, id: \.self) { m in
                                PillToggle(label: m.rawValue, selected: clicker.activationMode == m, accent: accent) {
                                    clicker.activationMode = m
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    var quickPresetsCard: some View {
        card(title: "QUICK SLOTS", icon: "bolt.fill") {
            if clicker.presets.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "tray").foregroundColor(.secondary)
                    Text("Save presets on the Presets tab, then assign them to quick slots here.")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { slot in
                        QuickSlotButton(slot: slot, clicker: clicker, accent: accent)
                    }
                }
            }
        }
    }

    var bigButton: some View {
        Button { clicker.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: clicker.isRunning ? "stop.fill" : "play.fill")
                Text(clicker.isRunning
                     ? "Stop  [\(clicker.hotkey.label)]"
                     : "Start Clicking  [\(clicker.hotkey.label)]")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(clicker.isRunning ? .red : accent)
        .disabled(!clicker.hasAccessibility)
        .animation(.easeInOut(duration: 0.18), value: clicker.isRunning)
    }

    var statsRow: some View {
        HStack {
            Label("\(clicker.sessionClicks) clicks", systemImage: "cursorarrow.click.2")
            Spacer()
            Text(String(format: "%.2f CPS  •  %.2f%% duty", clicker.cps, clicker.duty))
        }
        .font(.system(size: 10)).foregroundColor(.secondary)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    func card<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)

            content()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.08), lineWidth: 1))
    }
}

struct QuickSlotButton: View {
    let slot: Int
    @ObservedObject var clicker: AutoClicker
    let accent: Color
    @State private var showPicker = false

    var preset: ClickPreset? { clicker.presetForSlot(slot) }

    var body: some View {
        Button {
            if let p = preset { clicker.loadPreset(p) }
            else              { showPicker = true      }
        } label: {
            VStack(spacing: 3) {
                if let p = preset {
                    Text(p.name)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1).truncationMode(.tail)
                        .foregroundColor(accent)
                    Text(String(format: "%.2f", p.cps))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                    Text("CPS")
                        .font(.system(size: 8)).foregroundColor(.secondary)
                } else {
                    Image(systemName: "plus").font(.system(size: 14)).foregroundColor(.secondary)
                    Text("Empty").font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(preset != nil ? accent.opacity(0.08) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(preset != nil ? accent.opacity(0.25) : Color.secondary.opacity(0.12), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {

            if preset != nil {
                Button("Clear Slot") { clicker.assignSlot(slot, preset: nil) }
                Divider()
            }
            ForEach(clicker.presets) { p in
                Button(p.name) { clicker.assignSlot(slot, preset: p) }
            }
        }
        .popover(isPresented: $showPicker) {
            slotPickerPopover
        }
    }

    var slotPickerPopover: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Assign to Slot \(slot + 1)")
                .font(.system(size: 12, weight: .semibold))
                .padding(.bottom, 4)
            ForEach(clicker.presets) { p in
                Button {
                    clicker.assignSlot(slot, preset: p)
                    showPicker = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name).font(.system(size: 11, weight: .medium))
                            Text(String(format: "%.2f CPS  •  %.2f%%", p.cps, p.duty))
                                .font(.system(size: 9)).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Divider()
            Button("Cancel") { showPicker = false }
                .font(.system(size: 11)).foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .padding(12).frame(minWidth: 200)
    }
}

extension ContentView {
    var presetsTab: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Saved Presets").font(.system(size: 12, weight: .semibold))
                Spacer()
                ImportPresetButton(clicker: clicker)
                SavePresetButton(clicker: clicker, accent: accent)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider().opacity(0.3)
            if clicker.presets.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 32)).foregroundColor(.secondary.opacity(0.4))
                    Text("No Presets").font(.system(size: 13, weight: .semibold))
                    Text("Configure CPS and duty on the Main tab,\nthen tap Save to store it.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(clicker.presets) { p in
                        PresetRow(preset: p, accent: accent, clicker: clicker)
                    }
                    .onDelete { clicker.deletePresets(at: $0) }
                }
                .listStyle(.inset)
            }
        }
    }
}

extension ContentView {
    var settingsTab: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                card(title: "APPEARANCE", icon: "paintbrush") {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Accent Color").font(.system(size: 11)).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                ForEach(Array(kThemes.enumerated()), id: \.0) { i, t in
                                    Button { accentIndex = i } label: {
                                        Circle().fill(t.color).frame(width: 26, height: 26)
                                            .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: accentIndex == i ? 2.5 : 0))
                                            .shadow(color: accentIndex == i ? t.color.opacity(0.6) : .clear, radius: 5)
                                    }.buttonStyle(.plain).help(t.name)
                                }
                            }
                        }
                        Divider().opacity(0.3)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Background").font(.system(size: 11)).foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                ForEach(Array(kBgThemes.enumerated()), id: \.0) { i, t in
                                    Button { bgIndex = i } label: {
                                        RoundedRectangle(cornerRadius: 5).fill(t.color).frame(width: 30, height: 20)
                                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.white.opacity(0.9), lineWidth: bgIndex == i ? 2 : 0))
                                    }.buttonStyle(.plain).help(t.name)
                                }
                            }
                        }
                    }
                }
                card(title: "BUG REPORTS", icon: "ant") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Found a bug? DM Aero on Discord:").font(.system(size: 11))
                        HStack(spacing: 8) {
                            Text("5qvx")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.1)).cornerRadius(5)
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString("5qvx", forType: .string)
                            }.buttonStyle(.bordered).controlSize(.small)
                        }
                        Text("Attach a log file from Error Logs if asked.").font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
                card(title: "ERROR LOGS", icon: "doc.text") {
                    VStack(alignment: .leading, spacing: 8) {
                        let files = ErrorLogger.shared.logFiles
                        if files.isEmpty {
                            Text("No logs yet — errors are recorded here automatically.")
                                .font(.system(size: 10)).foregroundColor(.secondary)
                        } else {
                            ForEach(files.prefix(5), id: \.path) { url in
                                HStack {
                                    Text(url.lastPathComponent).font(.system(size: 10, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                    Button("Open") { NSWorkspace.shared.open(url) }
                                        .buttonStyle(.bordered).controlSize(.mini)
                                }
                            }
                        }
                        Button { ErrorLogger.shared.revealInFinder() } label: {
                            Label("Open Logs Folder in Finder", systemImage: "folder")
                        }.buttonStyle(.bordered).controlSize(.small)
                    }
                }
                card(title: "ABOUT", icon: "info.circle") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aerout Auto v1.0 Beta").font(.system(size: 12, weight: .semibold))
                        Text("by Aero  •  Discord: 5qvx").font(.system(size: 10)).foregroundColor(.secondary)
                        Text("Universal Binary — Intel + Apple Silicon  •  macOS 12+")
                            .font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }
            }
            .padding(14)
        }
    }
}

struct PillToggle: View {
    let label: String
    let selected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundColor(selected ? accent : .secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? accent.opacity(0.12) : Color.secondary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(selected ? accent.opacity(0.4) : Color.secondary.opacity(0.15), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct DecimalField: View {
    @Binding var value: Double
    let suffix: String
    let accent: Color
    let lo: Double
    let hi: Double
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(accent)
                .frame(width: 96)
                .multilineTextAlignment(.center)
                .focused($focused)
                .onAppear { text = String(format: "%.2f", value) }
                .onChange(of: text) { v in
                    let c = v.replacingOccurrences(of: ",", with: ".")
                    if let d = Double(c) { value = min(max(d, lo), hi) }
                }
                .onChange(of: value) { v in if !focused { text = String(format: "%.2f", v) } }
                .onChange(of: focused) { f in if !f { text = String(format: "%.2f", value) } }
                .onSubmit { text = String(format: "%.2f", value) }
            Text(suffix)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct SavePresetButton: View {
    var clicker: AutoClicker; var accent: Color
    @State private var show = false; @State private var name = ""
    var body: some View {
        Button {
            name = String(format: "%.2f CPS / %.2f%% duty", clicker.cps, clicker.duty)
            show = true
        } label: {
            Label("Save", systemImage: "plus").font(.system(size: 11))
        }
        .buttonStyle(.borderedProminent).tint(accent).controlSize(.small)
        .sheet(isPresented: $show) {
            VStack(spacing: 18) {
                Text("Save Preset").font(.system(size: 14, weight: .semibold))
                TextField("Preset name", text: $name)
                    .textFieldStyle(.roundedBorder).frame(width: 220)
                HStack(spacing: 10) {
                    Button("Cancel") { show = false }.keyboardShortcut(.cancelAction)
                    Button("Save") { clicker.saveAsPreset(name: name); show = false }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }.padding(24).frame(width: 290)
        }
    }
}

struct ImportPresetButton: View {
    var clicker: AutoClicker
    @State private var failed = false
    var body: some View {
        Button {
            let s = NSPasteboard.general.string(forType: .string) ?? ""
            if !clicker.importPreset(from: s) { failed = true }
        } label: {
            Label("Import", systemImage: "square.and.arrow.down").font(.system(size: 11))
        }
        .buttonStyle(.bordered).controlSize(.small)
        .help("Copy a share code to clipboard then click Import")
        .alert("Import Failed", isPresented: $failed) {
            Button("OK", role: .cancel) {}
        } message: { Text("No valid Aerout Auto preset code found in clipboard.") }
    }
}

struct PresetRow: View {
    var preset: ClickPreset; var accent: Color; var clicker: AutoClicker
    @State private var editing = false; @State private var editName = ""

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                if editing {
                    TextField("Name", text: $editName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { clicker.renamePreset(id: preset.id, to: editName); editing = false }
                } else {
                    Text(preset.name).font(.system(size: 12, weight: .medium))
                    Text(String(format: "%.2f CPS  •  %.2f%% duty  •  %@", preset.cps, preset.duty, preset.button.rawValue))
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
            }
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(preset.shareCode, forType: .string)
            } label: { Image(systemName: "square.and.arrow.up") }
            .buttonStyle(.borderless).help("Copy share code")

            Button {
                if editing { clicker.renamePreset(id: preset.id, to: editName) }
                else       { editName = preset.name }
                editing.toggle()
            } label: { Image(systemName: editing ? "checkmark" : "pencil") }
            .buttonStyle(.borderless)

            Button("Load") { clicker.loadPreset(preset) }
                .buttonStyle(.borderedProminent).tint(accent).controlSize(.mini)
        }
        .padding(.vertical, 3)
    }
}
