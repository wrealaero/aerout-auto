import SwiftUI

struct MenuBarView: View {
    @ObservedObject var clicker: AutoClicker
    var onOpenMain: () -> Void
    @AppStorage("accentIndex") private var accentIndex: Int = 0
    var accent: Color { kThemes[min(accentIndex, kThemes.count - 1)].color }

    var body: some View {
        VStack(spacing: 0) {
            titleRow
            Divider().opacity(0.3)
            editPanel
            Divider().opacity(0.3)
            controlRow
            if !clicker.presets.isEmpty {
                Divider().opacity(0.3)
                presetsPanel
            }
            Divider().opacity(0.3)
            Button { onOpenMain() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "macwindow").font(.system(size: 11))
                    Text("Open Full Settings").font(.system(size: 11))
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .frame(width: 280)
    }

    var titleRow: some View {
        HStack {
            Text("AEROUT AUTO")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(accent)
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(clicker.isRunning ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(clicker.isRunning ? "ON" : "OFF")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(clicker.isRunning ? .green : .secondary)
            }
            .animation(.easeInOut(duration: 0.2), value: clicker.isRunning)
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 9)
    }

    var editPanel: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text("CPS").font(.system(size: 9)).foregroundColor(.secondary)
                MiniDecimalField(value: $clicker.cps, lo: 0.01, hi: 1000, accent: accent)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 44).padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("Duty %").font(.system(size: 9)).foregroundColor(.secondary)
                MiniDecimalField(value: $clicker.duty, lo: 0.01, hi: 99.99, accent: accent)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 44).padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text("Interval").font(.system(size: 9)).foregroundColor(.secondary)
                Text(String(format: "%.1fms", clicker.intervalMs))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    var controlRow: some View {
        VStack(spacing: 8) {
            HStack {
                if clicker.isRunning || clicker.sessionClicks > 0 {
                    HStack(spacing: 3) {
                        Text("\(clicker.sessionClicks)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                        Text("clicks").font(.system(size: 9)).foregroundColor(.secondary)
                    }
                } else {
                    Text("\(clicker.mouseBtn.rawValue)  •  \(clicker.hotkey.label)  •  \(clicker.activationMode.rawValue)")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
            }
            Button { clicker.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: clicker.isRunning ? "stop.fill" : "play.fill")
                    Text(clicker.isRunning ? "Stop" : "Start Clicking").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderedProminent)
            .tint(clicker.isRunning ? .red : accent)
            .disabled(!clicker.hasAccessibility)
            .animation(.easeInOut(duration: 0.18), value: clicker.isRunning)

            if !clicker.hasAccessibility {
                Button("Grant Accessibility Permission") { clicker.requestAccessibility() }
                    .font(.system(size: 10)).foregroundColor(.orange).buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    var presetsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PRESETS")
                .font(.system(size: 9, weight: .bold)).foregroundColor(.secondary)
                .padding(.horizontal, 14).padding(.top, 9).padding(.bottom, 2)

            ForEach(clicker.presets.prefix(6)) { p in
                Button { clicker.loadPreset(p) } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(isActive(p) ? accent : Color.clear)
                            .overlay(Circle().stroke(accent.opacity(0.3), lineWidth: 1))
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name)
                                .font(.system(size: 11, weight: isActive(p) ? .semibold : .regular))
                                .foregroundColor(isActive(p) ? accent : .primary)
                            Text(String(format: "%.2f CPS  •  %.2f%%  •  %@", p.cps, p.duty, p.button.rawValue))
                                .font(.system(size: 9)).foregroundColor(.secondary)
                        }
                        Spacer()
                        if isActive(p) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(accent)
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(isActive(p) ? accent.opacity(0.06) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 6)
        }
    }
 
    func isActive(_ p: ClickPreset) -> Bool {
        abs(p.cps - clicker.cps) < 0.01 &&
        abs(p.duty - clicker.duty) < 0.01 &&
        p.button == clicker.mouseBtn
    }
}

struct MiniDecimalField: View {
    @Binding var value: Double
    let lo: Double
    let hi: Double
    let accent: Color
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .bold, design: .rounded))
            .foregroundColor(accent)
            .frame(width: 72)
            .multilineTextAlignment(.center)
            .focused($focused)
            .padding(.horizontal, 4).padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5).fill(focused ? accent.opacity(0.08) : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(focused ? accent.opacity(0.35) : Color.clear, lineWidth: 1))
            .onAppear { text = String(format: "%.2f", value) }
            .onChange(of: text) { v in
                let c = v.replacingOccurrences(of: ",", with: ".")
                if let d = Double(c) { value = min(max(d, lo), hi) }
            }
            .onChange(of: value) { v in if !focused { text = String(format: "%.2f", v) } }
            .onChange(of: focused) { f in
                if !f { text = String(format: "%.2f", value); AutoClicker.shared.saveSettings() }
            }
            .onSubmit { text = String(format: "%.2f", value); AutoClicker.shared.saveSettings() }
    }
}
