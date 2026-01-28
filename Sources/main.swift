import AppKit
import SwiftUI

// MARK: - Parse Arguments

let args = CommandLine.arguments
let runtime = args.count > 1 ? args[1] : "Claude"
let projectName = args.count > 2 ? args[2] : "Project"
let projectPath = args.count > 3 ? args[3] : ""
let isPermission = args.contains("permission")

// MARK: - Editor Config

enum OpenMethod {
    case cli(String)            // Standard CLI: "zed <path>", "code <path>"
    case urlScheme(String)      // URL scheme: "open warp://action/new_tab?path=<path>"
}

struct EditorConfig: Identifiable {
    let id: String              // Config key: "zed", "vscode", etc.
    let displayName: String     // Short label for buttons: "Zed", "VS Code"
    let appName: String         // macOS app name for AppleScript activation
    let openMethod: OpenMethod  // How to open a project path

    static let all: [String: EditorConfig] = [
        "zed":      EditorConfig(id: "zed",      displayName: "Zed",          appName: "Zed",                  openMethod: .cli("zed")),
        "vscode":   EditorConfig(id: "vscode",   displayName: "VS Code",      appName: "Visual Studio Code",   openMethod: .cli("code")),
        "code":     EditorConfig(id: "code",      displayName: "VS Code",      appName: "Visual Studio Code",   openMethod: .cli("code")),
        "cursor":   EditorConfig(id: "cursor",   displayName: "Cursor",       appName: "Cursor",               openMethod: .cli("cursor")),
        "windsurf": EditorConfig(id: "windsurf", displayName: "Windsurf",     appName: "Windsurf",             openMethod: .cli("windsurf")),
        "void":     EditorConfig(id: "void",     displayName: "Void",         appName: "Void",                 openMethod: .cli("void")),
        "sublime":  EditorConfig(id: "sublime",  displayName: "Sublime",      appName: "Sublime Text",         openMethod: .cli("subl")),
        "fleet":    EditorConfig(id: "fleet",    displayName: "Fleet",        appName: "Fleet",                openMethod: .cli("fleet")),
        "nova":     EditorConfig(id: "nova",     displayName: "Nova",         appName: "Nova",                 openMethod: .cli("nova")),
        "warp":     EditorConfig(id: "warp",     displayName: "Warp",         appName: "Warp",                 openMethod: .urlScheme("warp://action/new_tab?path=")),
    ]

    /// Load configured editors from ~/.config/claude-notify/config
    /// Supports both EDITOR=zed (single) and EDITORS=zed,vscode,warp (multiple)
    static func loadAll() -> [EditorConfig] {
        let configPath = NSString("~/.config/claude-notify/config").expandingTildeInPath
        guard let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return [all["zed"]!]
        }

        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Multi-editor: EDITORS=zed,vscode,warp
            if trimmed.hasPrefix("EDITORS=") {
                let value = String(trimmed.dropFirst("EDITORS=".count))
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                let keys = value.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                let configs = keys.compactMap { all[$0] }
                if !configs.isEmpty { return configs }
            }

            // Single editor (backward compatible): EDITOR=zed
            if trimmed.hasPrefix("EDITOR=") {
                let value = String(trimmed.dropFirst("EDITOR=".count))
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                if let config = all[value] {
                    return [config]
                }
            }
        }

        return [all["zed"]!]
    }
}

let editors = EditorConfig.loadAll()

// MARK: - Color Palette

extension Color {
    static let lavaOrange = Color(red: 1.0, green: 0.45, blue: 0.1)
    static let magmaRed = Color(red: 0.85, green: 0.15, blue: 0.08)
    static let emberGlow = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let darkCrust = Color(red: 0.08, green: 0.06, blue: 0.06)
    static let ashGray = Color(red: 0.55, green: 0.5, blue: 0.48)
}

// MARK: - Animated Ember Glow

struct EmberGlow: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            // Subtle animated lava glow at the bottom
            let gradient = Gradient(colors: [
                .magmaRed.opacity(0.3),
                .lavaOrange.opacity(0.15),
                .clear,
            ])

            let center = CGPoint(x: size.width * 0.5, y: size.height * 1.1)
            let startRadius: CGFloat = 0
            let endRadius = size.width * (0.7 + sin(phase) * 0.05)

            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    gradient,
                    center: center,
                    startRadius: startRadius,
                    endRadius: endRadius
                )
            )

            // Top edge subtle warm highlight
            let topGlow = Gradient(colors: [
                .emberGlow.opacity(0.08),
                .clear,
            ])
            context.fill(
                Path(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.3)),
                with: .linearGradient(
                    topGlow,
                    startPoint: CGPoint(x: size.width * 0.5, y: 0),
                    endPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.3)
                )
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Lava Button Style

struct LavaButtonStyle: ButtonStyle {
    var isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: isPrimary ? .semibold : .medium, design: .rounded))
            .foregroundStyle(isPrimary ? .white : .ashGray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                if isPrimary {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .lavaOrange,
                                    .magmaRed,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            .emberGlow.opacity(0.6),
                                            .magmaRed.opacity(0.3),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5
                                )
                        }
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Notification View

struct NotificationView: View {
    let runtime: String
    let projectName: String
    let isPermission: Bool
    let editors: [EditorConfig]
    let onOpen: (EditorConfig) -> Void
    let onDismiss: () -> Void

    @State private var appeared = false

    private var headerIcon: String {
        isPermission ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var headerText: String {
        isPermission ? "\(runtime) Needs Approval" : "\(runtime) Complete"
    }

    private var subtitleText: String {
        isPermission ? "Permission required to continue" : "Ready for your input"
    }

    private var isSingleEditor: Bool { editors.count == 1 }

    var body: some View {
        ZStack {
            // Pure frosted glass -- no dark mode override
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)

            // Animated ember glow -- subtle warmth, not overpowering
            EmberGlow()
                .opacity(0.5)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            // Outer border glow
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            .lavaOrange.opacity(0.4),
                            .magmaRed.opacity(0.2),
                            .lavaOrange.opacity(0.1),
                            .magmaRed.opacity(0.3),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )

            // Content
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.lavaOrange.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 16
                                )
                            )
                            .frame(width: 32, height: 32)

                        Image(systemName: headerIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.emberGlow, .lavaOrange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    Text(headerText)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 10)

                // Divider
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .lavaOrange.opacity(0.0),
                                .lavaOrange.opacity(0.25),
                                .magmaRed.opacity(0.25),
                                .magmaRed.opacity(0.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                // Project info
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(projectName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(subtitleText)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                // Buttons
                VStack(spacing: 8) {
                    // Editor buttons -- row of up to 3, wrap to second row if more
                    if isSingleEditor {
                        HStack(spacing: 10) {
                            Button("Dismiss", action: onDismiss)
                                .buttonStyle(LavaButtonStyle(isPrimary: false))

                            Button("Open Project") { onOpen(editors[0]) }
                                .buttonStyle(LavaButtonStyle(isPrimary: true))
                        }
                    } else {
                        // Multiple editors: show a button for each
                        let rows = editors.chunked(into: 3)
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack(spacing: 8) {
                                ForEach(row) { editor in
                                    Button(editor.displayName) { onOpen(editor) }
                                        .buttonStyle(LavaButtonStyle(isPrimary: true))
                                }
                            }
                        }

                        Button("Dismiss", action: onDismiss)
                            .buttonStyle(LavaButtonStyle(isPrimary: false))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)

                // Footer divider
                Rectangle()
                    .fill(.primary.opacity(0.06))
                    .frame(height: 0.5)
                    .padding(.horizontal, 18)

                // Footer
                VStack(spacing: 2) {
                    Text("\u{00A9} 2026 Andrew Naegele | All Rights Reserved")
                        .font(.system(size: 8.5, weight: .light, design: .rounded))
                        .foregroundStyle(.secondary.opacity(0.5))

                    Link("@andrew_naegele", destination: URL(string: "https://x.com/andrew_naegele")!)
                        .font(.system(size: 8.5, weight: .light, design: .rounded))
                        .foregroundStyle(Color.lavaOrange.opacity(0.5))
                }
                .padding(.top, 7)
                .padding(.bottom, 9)
            }
        }
        .frame(width: 300)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .magmaRed.opacity(0.25), radius: 30, x: 0, y: 8)
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

// MARK: - Array Chunking Helper

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - App Setup

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// Dynamic panel height: taller when multiple editors need extra button rows
let extraRows = editors.count > 1 ? max(0, (editors.count - 1) / 3) + 1 : 0  // +1 for dismiss row
let panelHeight: CGFloat = 230 + CGFloat(extraRows) * 44
let panelWidth: CGFloat = 320

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
panel.hasShadow = false  // We handle shadows in SwiftUI
panel.hidesOnDeactivate = false

var dismissTimer: Timer?

func dismiss() {
    dismissTimer?.invalidate()
    panel.close()
    NSApp.terminate(nil)
}

func openProject(with config: EditorConfig) {
    dismissTimer?.invalidate()
    panel.close()

    if !projectPath.isEmpty {
        let activate = Process()
        activate.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        activate.arguments = ["-e", "tell application \"\(config.appName)\" to activate"]
        try? activate.run()
        activate.waitUntilExit()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch config.openMethod {
            case .cli(let command):
                let editor = Process()
                editor.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                editor.arguments = [command, projectPath]
                try? editor.run()
                editor.waitUntilExit()
            case .urlScheme(let scheme):
                let urlString = scheme + projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }
            NSApp.terminate(nil)
        }
    } else {
        NSApp.terminate(nil)
    }
}

let hostingView = NSHostingView(rootView:
    NotificationView(
        runtime: runtime,
        projectName: projectName,
        isPermission: isPermission,
        editors: editors,
        onOpen: { config in openProject(with: config) },
        onDismiss: dismiss
    )
    .padding(10) // Extra space for shadow rendering
)

panel.contentView = hostingView

// Position: top-right corner
if let screen = NSScreen.main {
    let screenFrame = screen.visibleFrame
    let x = screenFrame.maxX - panelWidth - 12
    let y = screenFrame.maxY - panelHeight - 12
    panel.setFrameOrigin(NSPoint(x: x, y: y))
}

panel.orderFrontRegardless()

dismissTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
    dismiss()
}

// Play sound -- Ping for permission prompts, Glass for completions
let soundProcess = Process()
soundProcess.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
soundProcess.arguments = [isPermission
    ? "/System/Library/Sounds/Ping.aiff"
    : "/System/Library/Sounds/Glass.aiff"]
try? soundProcess.run()

app.run()
