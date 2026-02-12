import AppKit
import SwiftUI

// MARK: - Parse Arguments
// Args: runtime projectName projectPath editor ttyDevice [mode]

let args = CommandLine.arguments
let runtime = args.count > 1 ? args[1] : "Claude"
let projectName = args.count > 2 ? args[2] : "Project"
let projectPath = args.count > 3 ? args[3] : ""
let editorArg = args.count > 4 ? args[4] : "Terminal"
let ttyDevice = args.count > 5 ? args[5] : "none"
let mode = args.count > 6 ? args[6] : ""

let isPermission = mode == "permission"
let hasTTY = ttyDevice != "none" && !ttyDevice.isEmpty

// MARK: - Editor

enum Editor: String, CaseIterable {
    case zed = "Zed"
    case cursor = "Cursor"
    case vscode = "VSCode"
    case windsurf = "Windsurf"
    case void_ = "Void"
    case sublime = "Sublime"
    case fleet = "Fleet"
    case nova = "Nova"
    case warp = "Warp"
    case iterm = "iTerm"
    case wezterm = "WezTerm"
    case alacritty = "Alacritty"
    case ghostty = "Ghostty"
    case terminal = "Terminal"
    case unknown = "Unknown"

    var appName: String {
        switch self {
        case .zed: return "Zed"
        case .cursor: return "Cursor"
        case .vscode: return "Visual Studio Code"
        case .windsurf: return "Windsurf"
        case .void_: return "Void"
        case .sublime: return "Sublime Text"
        case .fleet: return "Fleet"
        case .nova: return "Nova"
        case .warp: return "Warp"
        case .iterm: return "iTerm2"
        case .wezterm: return "WezTerm"
        case .alacritty: return "Alacritty"
        case .ghostty: return "Ghostty"
        case .terminal, .unknown: return "Terminal"
        }
    }

    var openCommand: String? {
        switch self {
        case .zed: return "zed"
        case .cursor: return "cursor"
        case .vscode: return "code"
        case .windsurf: return "windsurf"
        case .void_: return "void"
        case .sublime: return "subl"
        case .fleet: return "fleet"
        default: return nil
        }
    }

    var isTerminal: Bool {
        switch self {
        case .warp, .iterm, .wezterm, .alacritty, .ghostty, .terminal, .unknown:
            return true
        default: return false
        }
    }

    var iconName: String {
        switch self {
        case .zed, .cursor, .vscode, .windsurf, .void_, .sublime, .fleet, .nova:
            return "chevron.left.forwardslash.chevron.right"
        case .warp, .iterm, .wezterm, .alacritty, .ghostty, .terminal:
            return "rectangle.topthird.inset.filled"
        case .unknown:
            return "questionmark.app"
        }
    }

    var displayName: String {
        switch self {
        case .void_: return "Void"
        default: return rawValue
        }
    }

    static func from(_ string: String) -> Editor {
        let lower = string.lowercased()
        for e in allCases where e.rawValue.lowercased() == lower { return e }
        if lower.contains("code") || lower.contains("vscode") { return .vscode }
        if lower.contains("cursor") { return .cursor }
        if lower.contains("zed") { return .zed }
        if lower.contains("windsurf") { return .windsurf }
        if lower.contains("iterm") { return .iterm }
        if lower.contains("ghostty") { return .ghostty }
        return .terminal
    }
}

let editor = Editor.from(editorArg)

// MARK: - Terminal Focusing

func focusTerminalWindowByTTY(_ tty: String) -> Bool {
    let ttyName = tty.replacingOccurrences(of: "/dev/", with: "")
    let script = """
    tell application "Terminal"
        activate
        repeat with w in every window
            repeat with t in every tab of w
                if tty of t contains "\(ttyName)" then
                    set index of w to 1
                    set selected tab of w to t
                    return true
                end if
            end repeat
        end repeat
        return false
    end tell
    """
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", script]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    try? proc.run()
    proc.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return out.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
}

func focusiTermWindowByTTY(_ tty: String) -> Bool {
    let ttyName = tty.replacingOccurrences(of: "/dev/", with: "")
    let script = """
    tell application "iTerm2"
        activate
        repeat with w in every window
            repeat with t in every tab of w
                repeat with s in every session of t
                    if tty of s contains "\(ttyName)" then
                        select t
                        select s
                        set index of w to 1
                        return true
                    end if
                end repeat
            end repeat
        end repeat
        return false
    end tell
    """
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    proc.arguments = ["-e", script]
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    try? proc.run()
    proc.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return out.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
}

// MARK: - Notification Stacking

let stackDir = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".cache/claude-notify/stack")

func ensureStackDir() {
    try? FileManager.default.createDirectory(at: stackDir, withIntermediateDirectories: true)
}

func claimSlot() -> Int {
    ensureStackDir()
    for slot in 0..<20 {
        let lockFile = stackDir.appendingPathComponent("slot-\(slot).lock")
        if !FileManager.default.fileExists(atPath: lockFile.path) {
            let pid = "\(ProcessInfo.processInfo.processIdentifier)"
            try? pid.write(to: lockFile, atomically: true, encoding: .utf8)
            return slot
        }
        if let pidStr = try? String(contentsOf: lockFile, encoding: .utf8),
           let pid = Int32(pidStr.trimmingCharacters(in: .whitespacesAndNewlines)) {
            if kill(pid, 0) != 0 {
                let myPid = "\(ProcessInfo.processInfo.processIdentifier)"
                try? myPid.write(to: lockFile, atomically: true, encoding: .utf8)
                return slot
            }
        }
    }
    return 0
}

func releaseSlot(_ slot: Int) {
    let lockFile = stackDir.appendingPathComponent("slot-\(slot).lock")
    try? FileManager.default.removeItem(at: lockFile)
}

let notificationSlot = claimSlot()

// MARK: - Runtime & Editor Brand Colors

extension Editor {
    /// Brand color for the accent bar -- each app gets its own identity
    var brandColor: Color {
        switch self {
        case .cursor:    return Color(red: 0.15, green: 0.15, blue: 0.18)   // Near-black
        case .vscode:    return Color(red: 0.18, green: 0.50, blue: 0.90)   // Microsoft blue
        case .zed:       return Color(red: 0.30, green: 0.65, blue: 0.95)   // Zed blue
        case .windsurf:  return Color(red: 0.10, green: 0.75, blue: 0.65)   // Teal
        case .void_:     return Color(red: 0.50, green: 0.50, blue: 0.55)   // Grey
        case .sublime:   return Color(red: 1.0, green: 0.60, blue: 0.20)    // Sublime orange
        case .fleet:     return Color(red: 0.55, green: 0.35, blue: 0.90)   // JetBrains purple
        case .nova:      return Color(red: 0.20, green: 0.55, blue: 0.95)   // Nova blue
        case .warp:      return Color(red: 0.22, green: 0.82, blue: 0.70)   // Warp teal
        case .iterm:     return Color(red: 0.30, green: 0.72, blue: 0.30)   // Green
        case .wezterm:   return Color(red: 0.60, green: 0.40, blue: 0.85)   // Purple
        case .alacritty: return Color(red: 0.95, green: 0.60, blue: 0.20)   // Orange
        case .ghostty:   return Color(red: 0.45, green: 0.45, blue: 0.50)   // Grey
        case .terminal:  return Color(red: 0.35, green: 0.35, blue: 0.40)   // Dark grey
        case .unknown:   return Color(red: 0.50, green: 0.50, blue: 0.55)
        }
    }
}

/// Runtime brand color (Claude=orange, OpenCode=teal)
func runtimeColor(_ name: String) -> Color {
    if name.lowercased().contains("opencode") {
        return Color(red: 0.10, green: 0.75, blue: 0.65)  // OpenCode teal/green
    }
    return Color(red: 0.95, green: 0.48, blue: 0.15)      // Claude orange
}

// MARK: - Design System

extension Color {
    // Timer
    static let timerRed = Color(red: 1.0, green: 0.22, blue: 0.22)
    static let timerGlow = Color(red: 1.0, green: 0.30, blue: 0.30)

    // Text
    static let inkPrimary = Color(red: 0.10, green: 0.10, blue: 0.12)
    static let inkSecondary = Color(red: 0.35, green: 0.35, blue: 0.40)
    static let inkTertiary = Color(red: 0.52, green: 0.52, blue: 0.56)

    // Surfaces
    static let closeBg = Color(red: 0.90, green: 0.90, blue: 0.92)
    static let trackBg = Color(red: 0.88, green: 0.88, blue: 0.91)
}

// MARK: - Accent Pill

struct AccentPill: View {
    let color: Color
    @State private var shimmer: CGFloat = 0

    var body: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.7), color, color.opacity(0.7)],
                    startPoint: UnitPoint(x: 0.5, y: shimmer - 0.5),
                    endPoint: UnitPoint(x: 0.5, y: shimmer + 0.5)
                )
            )
            .frame(width: 6.5)
            .shadow(color: color.opacity(0.55), radius: 6, x: 0, y: 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    shimmer = 1
                }
            }
    }
}

// MARK: - 3D Button Styles

struct ActionButtonStyle: ButtonStyle {
    let fill1: Color
    let fill2: Color

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // Base gradient (brain-style 160deg slate-ish, but using runtime color)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [fill1, fill2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Top inset highlight (white light from above)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(pressed ? 0.10 : 0.30),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    // Bottom inset shadow (dark from below)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(pressed ? 0.15 : 0.08),
                                ],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(fill2.opacity(0.5), lineWidth: 0.5)
                }
            )
            // Subtle drop shadow, not a colored glow
            .shadow(color: .black.opacity(pressed ? 0.06 : 0.15), radius: pressed ? 2 : 6, x: 0, y: pressed ? 1 : 3)
            .scaleEffect(pressed ? 0.98 : 1)
            .offset(y: pressed ? 1 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
    }
}

struct DismissButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    // Base fill
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(red: 0.93, green: 0.93, blue: 0.95))

                    // Top inset highlight
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(pressed ? 0.3 : 0.65),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )

                    // Bottom inset shadow
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(pressed ? 0.06 : 0.03),
                                ],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )

                    // Border
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color(red: 0.78, green: 0.78, blue: 0.82), lineWidth: 0.5)
                }
            )
            .shadow(color: .black.opacity(pressed ? 0.03 : 0.10), radius: pressed ? 1 : 4, x: 0, y: pressed ? 0.5 : 2)
            .scaleEffect(pressed ? 0.98 : 1)
            .offset(y: pressed ? 1 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
    }
}

// MARK: - Timer Bar with Glowing Orb

struct TimerBar: View {
    let totalDuration: Double
    @State private var progress: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let fillW = w * progress

            ZStack(alignment: .leading) {
                // Track pill
                Capsule(style: .continuous)
                    .fill(Color.trackBg)
                    .frame(height: 3)

                // Red fill pill
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.timerRed, .timerRed.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(fillW, 3), height: 3)
                    .shadow(color: .timerGlow.opacity(0.4), radius: 3, x: 0, y: 0)

                // Glowing red orb at the leading edge
                Circle()
                    .fill(Color.timerRed)
                    .frame(width: 6, height: 6)
                    .shadow(color: .timerRed.opacity(0.9), radius: 4, x: 0, y: 0)
                    .shadow(color: .timerGlow.opacity(0.5), radius: 7, x: 0, y: 0)
                    .offset(x: max(fillW - 3, 0))
            }
            .onAppear {
                withAnimation(.linear(duration: totalDuration)) {
                    progress = 0
                }
            }
        }
        .frame(height: 7)
    }
}

// MARK: - Traffic Light Close Button

struct TrafficLightClose: View {
    let action: () -> Void
    @State private var isHovered = false

    // macOS native close button: red circle, dark gray center dot, × on hover
    private let closeRed = Color(red: 1.0, green: 0.27, blue: 0.23)
    private let closeBorder = Color(red: 0.87, green: 0.19, blue: 0.17)

    var body: some View {
        Button(action: action) {
            ZStack {
                // Red circle with subtle top-to-bottom gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.40, blue: 0.35),
                                closeRed,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 16, height: 16)

                // Border ring
                Circle()
                    .strokeBorder(closeBorder.opacity(0.55), lineWidth: 0.5)
                    .frame(width: 16, height: 16)

                if isHovered {
                    // × on hover
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(Color(red: 0.35, green: 0.05, blue: 0.02).opacity(0.85))
                } else {
                    // Dark center dot (always visible)
                    Circle()
                        .fill(Color(red: 0.35, green: 0.05, blue: 0.02).opacity(0.45))
                        .frame(width: 5, height: 5)
                }
            }
            .shadow(color: closeBorder.opacity(0.25), radius: 0.5, x: 0, y: 0.5)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.10)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Notification View

struct NotificationView: View {
    let runtime: String
    let projectName: String
    let editor: Editor
    let isPermission: Bool
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    private var barColor: Color {
        runtimeColor(runtime)
    }

    private var btnColor1: Color {
        runtimeColor(runtime)
    }
    private var btnColor2: Color {
        runtimeColor(runtime).opacity(0.85)
    }

    private var statusIcon: String {
        isPermission ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var statusLabel: String {
        isPermission ? "Permission Needed" : "Complete"
    }

    private var subtitle: String {
        isPermission ? "Waiting for your approval" : "Ready for your input"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left accent pill -- color-coded to runtime
            AccentPill(color: barColor)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .padding(.leading, 10)

            // Main content
            VStack(alignment: .leading, spacing: 0) {
                // ── Title bar: icon + title ... close button on right ──
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [barColor, barColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: barColor.opacity(0.35), radius: 3, x: 0, y: 1)

                    Text(runtime)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color.inkPrimary)

                    Text(statusLabel)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.inkSecondary)

                    Spacer()

                    TrafficLightClose(action: onDismiss)
                }
                .padding(.top, 14)
                .padding(.leading, 10)
                .padding(.trailing, 10)

                Spacer(minLength: 0)

                // ── Project info ──
                HStack(spacing: 5) {
                    Image(systemName: editor.iconName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.inkTertiary)

                    Text(projectName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.inkPrimary)
                        .lineLimit(1)

                    Text("in \(editor.displayName)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.inkTertiary)
                }
                .padding(.horizontal, 12)

                // Subtitle
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color.inkSecondary)
                    .padding(.top, 2)
                    .padding(.horizontal, 12)

                Spacer(minLength: 0)

                // ── Buttons (uniform width) ──
                HStack(spacing: 8) {
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(DismissButtonStyle())

                    Button("Open in \(editor.displayName)", action: onOpen)
                        .buttonStyle(ActionButtonStyle(fill1: btnColor1, fill2: btnColor2))
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

                // ── Timer pill ──
                TimerBar(totalDuration: 30)
                    .padding(.leading, 12)
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 350)
        .background {
            ZStack {
                // Opaque white base
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.98, green: 0.98, blue: 0.99))

                // Top luminance
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.5)
                        )
                    )

                // Border
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white, Color(red: 0.80, green: 0.80, blue: 0.83)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.20), radius: 30, x: 0, y: 12)
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        .scaleEffect(appeared ? 1.0 : 0.90)
        .opacity(appeared ? 1.0 : 0)
        .offset(x: appeared ? 0 : 30)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                appeared = true
            }
        }
    }
}

// MARK: - App

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let panelWidth: CGFloat = 380
let panelHeight: CGFloat = 195

let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
    styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
    backing: .buffered,
    defer: false
)

panel.isMovableByWindowBackground = true
panel.backgroundColor = .clear
panel.isOpaque = false
panel.level = .screenSaver
panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
panel.hasShadow = false
panel.hidesOnDeactivate = false

var dismissTimer: Timer?

func dismiss() {
    dismissTimer?.invalidate()
    releaseSlot(notificationSlot)

    // Animate out
    NSAnimationContext.runAnimationGroup { ctx in
        ctx.duration = 0.2
        ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
        panel.animator().alphaValue = 0
    } completionHandler: {
        panel.close()
        NSApp.terminate(nil)
    }
}

func openProject() {
    dismissTimer?.invalidate()
    releaseSlot(notificationSlot)
    panel.close()

    if editor.isTerminal && hasTTY {
        var focused = false
        switch editor {
        case .terminal: focused = focusTerminalWindowByTTY(ttyDevice)
        case .iterm: focused = focusiTermWindowByTTY(ttyDevice)
        default: break
        }
        if !focused {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", "tell application \"\(editor.appName)\" to activate"]
            try? p.run()
            p.waitUntilExit()
        }
        NSApp.terminate(nil)
    } else {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", "tell application \"\(editor.appName)\" to activate"]
        try? p.run()
        p.waitUntilExit()

        if !projectPath.isEmpty, let cmd = editor.openCommand {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let o = Process()
                o.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                o.arguments = [cmd, projectPath]
                try? o.run()
                o.waitUntilExit()
                NSApp.terminate(nil)
            }
        } else {
            NSApp.terminate(nil)
        }
    }
}

let hostingView = NSHostingView(rootView:
    NotificationView(
        runtime: runtime,
        projectName: projectName,
        editor: editor,
        isPermission: isPermission,
        onOpen: openProject,
        onDismiss: dismiss
    )
    .padding(EdgeInsets(top: 4, leading: 12, bottom: 14, trailing: 12))
)

panel.contentView = hostingView

if let screen = NSScreen.main {
    let frame = screen.visibleFrame
    let x = frame.maxX - panelWidth - 16
    let spacing = CGFloat(notificationSlot) * (panelHeight + 10)
    let y = frame.maxY - panelHeight - 16 - spacing
    panel.setFrameOrigin(NSPoint(x: x, y: y))
}

panel.orderFrontRegardless()

dismissTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
    dismiss()
}

// Sound
let soundFile = isPermission
    ? "/System/Library/Sounds/Tink.aiff"
    : "/System/Library/Sounds/Glass.aiff"
let snd = Process()
snd.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
snd.arguments = [soundFile]
try? snd.run()

app.run()
