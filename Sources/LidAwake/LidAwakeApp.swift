import AppKit
import Foundation
import SwiftUI

@main
struct LidAwakeApp: App {
    @StateObject private var controller = SleepController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(controller)
                .frame(minWidth: 430)
        }
        .windowResizability(.contentSize)
    }
}

private struct ContentView: View {
    @EnvironmentObject private var controller: SleepController
    @State private var durationChoice = DurationChoice.hours(2)
    @State private var customHours = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("别睡")
                    .font(.title2.bold())
                Text("在指定时间内阻止 MacBook 因合盖进入睡眠。")
                    .foregroundStyle(.secondary)
            }

            statusCard

            if controller.passwordlessReady == false {
                passwordlessBanner
            }

            if !controller.isActive {
                VStack(alignment: .leading, spacing: 10) {
                    Text("持续时间")
                        .font(.headline)

                    Picker("持续时间", selection: $durationChoice) {
                        Text("1 小时").tag(DurationChoice.hours(1))
                        Text("2 小时").tag(DurationChoice.hours(2))
                        Text("4 小时").tag(DurationChoice.hours(4))
                        Text("8 小时").tag(DurationChoice.hours(8))
                        Text("自定义").tag(DurationChoice.custom)
                    }
                    .pickerStyle(.segmented)

                    if durationChoice == .custom {
                        HStack(spacing: 8) {
                            TextField("例如 3.5", text: $customHours)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                            Text("小时（最多 24 小时）")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Button("刷新状态") {
                    controller.refreshPowerState()
                }
                .disabled(controller.isWorking)

                Spacer()

                if controller.isSleepDisabled {
                    Button("立即恢复合盖休眠", role: .destructive) {
                        controller.stop()
                    }
                    .disabled(controller.isWorking)
                } else {
                    Button("开始保持运行") {
                        controller.start(for: selectedDuration)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.isWorking || selectedDuration == nil)
                }
            }

            if controller.isWorking {
                ProgressView("正在应用设置…")
                    .controlSize(.small)
            }

            if let errorMessage = controller.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            if let infoMessage = controller.infoMessage {
                Text(infoMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 10) {
                Button("检查更新") {
                    UpdatePrompt.show()
                }
                .disabled(controller.isWorking)

                Spacer()

                Button("退出应用") {
                    ExitPrompt.request(isProtectionActive: controller.isSleepDisabled)
                }
                .disabled(controller.isWorking)
            }

            VStack(alignment: .leading, spacing: 5) {
                Label("建议连接电源，并让电脑放在通风、坚硬的表面上。", systemImage: "powerplug")
                Label("合盖运行时不要把电脑放进包里，以免过热。", systemImage: "thermometer.medium")
                Label("到期或点“立即恢复合盖休眠”后，原有的合盖睡眠行为会恢复。", systemImage: "clock.arrow.circlepath")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .task {
            controller.refreshPowerState()
        }
    }

    private var selectedDuration: TimeInterval? {
        switch durationChoice {
        case let .hours(hours):
            return hours * 60 * 60
        case .custom:
            guard let hours = Double(customHours), hours > 0, hours <= 24 else {
                return nil
            }
            return hours * 60 * 60
        }
    }

    @ViewBuilder
    private var passwordlessBanner: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "key.horizontal")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("尚未启用免密码模式")
                    .font(.callout.weight(.medium))
                Text("启用后，开始与恢复操作不再询问管理员密码（仅需一次性授权）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button("一键启用") {
                controller.installPasswordless()
            }
            .disabled(controller.isWorking)
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var statusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: controller.isActive ? "lock.fill" : "moon.zzz")
                .font(.title2)
                .foregroundStyle(controller.isActive ? .green : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                if controller.isActive, let endDate = controller.endDate {
                    Text("合盖睡眠已暂停")
                        .font(.headline)
                    Text("将在 \(endDate.formatted(date: .omitted, time: .shortened)) 恢复（剩余 \(controller.remainingText)）")
                        .foregroundStyle(.secondary)
                } else if controller.isSleepDisabled {
                    Text("系统当前已禁止合盖睡眠")
                        .font(.headline)
                    Text("这可能由本程序以外的设置启用；可使用“立即恢复合盖休眠”。")
                        .foregroundStyle(.secondary)
                } else {
                    Text("合盖睡眠正常")
                        .font(.headline)
                    Text(controller.passwordlessReady == true
                         ? "选择时长后开始。"
                         : "选择时长后开始；首次使用需先启用免密码模式。")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private enum DurationChoice: Hashable {
    case hours(Double)
    case custom
}

@MainActor
private final class SleepController: ObservableObject {
    @Published private(set) var isSleepDisabled = false
    @Published private(set) var endDate: Date?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published private(set) var passwordlessReady: Bool?
    @Published private(set) var infoMessage: String?

    private let defaults = UserDefaults.standard
    private let endDateKey = "lidAwake.endDate"
    private var ticker: Timer?

    init() {
        endDate = defaults.object(forKey: endDateKey) as? Date
        startTicker()
    }


    var isActive: Bool {
        guard let endDate else { return false }
        return endDate > Date() && isSleepDisabled
    }

    var remainingText: String {
        guard let endDate else { return "0 分钟" }
        let seconds = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        }
        if minutes > 0 {
            return "\(minutes) 分钟"
        }
        return "\(remainingSeconds) 秒"
    }

    func start(for duration: TimeInterval?) {
        guard let duration else {
            errorMessage = "请输入大于 0、且最多 24 小时的时长。"
            return
        }

        isWorking = true
        errorMessage = nil
        infoMessage = nil
        let newEndDate = Date().addingTimeInterval(duration)

        Task {
            do {
                try await PrivilegedPowerControl.start(for: Int(duration))
                endDate = newEndDate
                defaults.set(newEndDate, forKey: endDateKey)
                isSleepDisabled = true
                passwordlessReady = true
            } catch {
                errorMessage = errorText(for: error, action: "未能开启")
                refreshPowerState(probe: false)
            }
            isWorking = false
        }
    }

    func stop() {
        isWorking = true
        errorMessage = nil
        infoMessage = nil

        Task {
            do {
                try await PrivilegedPowerControl.stop()
                endDate = nil
                defaults.removeObject(forKey: endDateKey)
                isSleepDisabled = false
                passwordlessReady = true
            } catch {
                errorMessage = errorText(for: error, action: "未能恢复")
                refreshPowerState(probe: false)
            }
            isWorking = false
        }
    }

    func refreshPowerState(probe: Bool = true) {
        Task {
            do {
                let output = try await CommandRunner.output(executable: "/usr/bin/pmset", arguments: ["-g"])
                isSleepDisabled = output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil

                if !isSleepDisabled {
                    endDate = nil
                    defaults.removeObject(forKey: endDateKey)
                    if probe {
                        await probePasswordless()
                    }
                }
            } catch {
                errorMessage = "无法读取电源状态：\(error.localizedDescription)"
            }
        }
    }

    func installPasswordless() {
        isWorking = true
        errorMessage = nil
        infoMessage = nil

        Task {
            do {
                try await PasswordlessSetup.install()
            } catch {
                let text = error.localizedDescription
                if text == "已取消" {
                    infoMessage = "已取消启用操作，系统设置未发生变更。"
                } else {
                    errorMessage = "启用失败：\(text)"
                }
                isWorking = false
                return
            }
            infoMessage = "免密码模式已启用，后续操作不再需要输入密码。"
            isWorking = false
            await probePasswordless()
        }
    }

    /// 在“系统合盖睡眠正常”的状态下，用一条无副作用的命令探测免密码模式是否已配置。
    private func probePasswordless() async {
        guard !isSleepDisabled, !isWorking, !isActive else { return }
        do {
            try await CommandRunner.runSudo(executable: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "0"])
            if !isSleepDisabled && !isWorking {
                passwordlessReady = true
            }
        } catch {
            if !isSleepDisabled && !isWorking {
                passwordlessReady = false
            }
        }
    }

    private func errorText(for error: Error, action: String) -> String {
        if let commandError = error as? CommandError, commandError.isPasswordRequired {
            passwordlessReady = false
            return "\(action)：需要先启用免密码模式，请点击上方「一键启用」。"
        }
        return "\(action)：\(error.localizedDescription)"
    }

    private func startTicker() {
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let endDate = self.endDate else { return }
                if endDate <= Date() {
                    self.refreshPowerState()
                }
            }
        }
    }
}

private enum PrivilegedPowerControl {
    private static let stateDirectory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("LidAwake", isDirectory: true)
    private static var tokenURL: URL {
        stateDirectory.appendingPathComponent("timer-token")
    }

    static func start(for seconds: Int) async throws {
        try FileManager.default.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        let token = UUID().uuidString.lowercased()
        try Data(token.utf8).write(to: tokenURL)

        do {
            try await CommandRunner.runSudo(executable: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "1"])
        } catch {
            try? FileManager.default.removeItem(at: tokenURL)
            throw error
        }

        do {
            try CommandRunner.spawnTimer(seconds: seconds, token: token, tokenPath: tokenURL.path)
        } catch {
            try? FileManager.default.removeItem(at: tokenURL)
            try? await CommandRunner.runSudo(executable: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "0"])
            throw error
        }
    }

    static func stop() async throws {
        try? FileManager.default.removeItem(at: tokenURL)
        try await CommandRunner.runSudo(executable: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "0"])
    }
}

@MainActor
private enum UpdatePrompt {
    static func show() {
        let alert = NSAlert()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        alert.messageText = "检查更新"
        alert.informativeText = "当前版本：\(version)。\n\n此应用目前是本地构建版本，尚未配置远程更新服务。获取新版本时，请使用最新构建的应用包替换当前应用。"
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }
}

@MainActor
private enum ExitPrompt {
    static func request(isProtectionActive: Bool) {
        let alert = NSAlert()
        alert.messageText = "退出“别睡”？"
        alert.informativeText = isProtectionActive
            ? "合盖防睡眠会继续生效，直到设定时间结束或你手动恢复合盖休眠。"
            : "退出不会更改当前的合盖睡眠设置。"
        alert.addButton(withTitle: "退出")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            NSApp.terminate(nil)
        }
    }
}

private enum PasswordlessSetup {
    /// 一次性写入 /etc/sudoers.d/lidawake 白名单：
    /// 仅允许当前用户免密执行 pmset -a disablesleep 1 / 0 这两条字面量命令。
    static func install() async throws {
        let userName = NSUserName()
        guard userName.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else {
            throw CommandError(message: "当前用户名包含特殊字符，请在终端运行 Scripts/install-passwordless.zsh 完成配置。")
        }

        let rule = "\(userName) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0"
        let shellCommand = "T=$(/usr/bin/mktemp /tmp/lidawake-sudoers.XXXXXX); printf '%s\\n' '\(rule)' > $T && /usr/sbin/visudo -cf $T && /usr/bin/install -o root -g wheel -m 0440 $T /etc/sudoers.d/lidawake && /bin/rm -f $T"

        let escaped = shellCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(escaped)\" with administrator privileges with prompt \"“别睡”需要一次性启用免密码模式（仅需输入一次管理员密码）。\""

        do {
            try await CommandRunner.runOSAScript(source)
        } catch {
            let text = error.localizedDescription
            if text.localizedCaseInsensitiveContains("user canceled") || text.contains("(-128)") {
                throw CommandError(message: "已取消")
            }
            throw error
        }
    }
}

private enum CommandRunner {
    /// 非交互式 sudo：依赖一次性配置的免密白名单（sudo -n），不会弹出密码提示。
    static func runSudo(executable: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                process.arguments = ["-n", executable] + arguments
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                process.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(decoding: outputData, as: UTF8.self)
                    let error = String(decoding: errorData, as: UTF8.self)

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CommandError(message: error.isEmpty ? output : error))
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// 启动用户态后台定时进程：到期且定时标识仍未被替换时，免密恢复合盖睡眠。
    /// 以当前用户身份运行，应用退出后仍会继续计时。
    static func spawnTimer(seconds: Int, token: String, tokenPath: String) throws {
        let script = "/bin/sleep \(seconds); if [ \"$(/bin/cat \(shellQuote(tokenPath)) 2>/dev/null)\" = \(shellQuote(token)) ]; then /usr/bin/sudo -n /usr/bin/pmset -a disablesleep 0 && /bin/rm -f \(shellQuote(tokenPath)); fi"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    static func runOSAScript(_ source: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", source]
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                process.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(decoding: outputData, as: UTF8.self)
                    let error = String(decoding: errorData, as: UTF8.self)

                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CommandError(message: error.isEmpty ? output : error))
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    static func output(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                process.terminationHandler = { process in
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(decoding: outputData, as: UTF8.self)
                    let error = String(decoding: errorData, as: UTF8.self)

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: CommandError(message: error.isEmpty ? output : error))
                    }
                }

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private struct CommandError: LocalizedError {
    let message: String

    var isPasswordRequired: Bool {
        message.localizedCaseInsensitiveContains("password is required")
    }

    var errorDescription: String? {
        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "系统命令执行失败。"
            : message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
