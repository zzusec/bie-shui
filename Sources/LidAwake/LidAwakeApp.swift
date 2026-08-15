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
                        guard let password = PasswordPrompt.request() else { return }
                        controller.stop(using: password)
                    }
                    .disabled(controller.isWorking)
                } else {
                    Button("开始保持运行") {
                        guard let password = PasswordPrompt.request() else { return }
                        controller.start(for: selectedDuration, using: password)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.isWorking || selectedDuration == nil)
                }
            }

            if controller.isWorking {
                ProgressView("正在请求系统管理员授权…")
                    .controlSize(.small)
            }

            if let errorMessage = controller.errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
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
                    Text("选择时长后开始。首次操作会要求输入管理员密码。")
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

    func start(for duration: TimeInterval?, using password: String) {
        guard let duration else {
            errorMessage = "请输入大于 0、且最多 24 小时的时长。"
            return
        }

        isWorking = true
        errorMessage = nil
        let newEndDate = Date().addingTimeInterval(duration)

        Task {
            do {
                try await PrivilegedPowerControl.start(for: Int(duration), using: password)
                endDate = newEndDate
                defaults.set(newEndDate, forKey: endDateKey)
                isSleepDisabled = true
            } catch {
                errorMessage = "未能开启：\(error.localizedDescription)"
                refreshPowerState()
            }
            isWorking = false
        }
    }

    func stop(using password: String) {
        isWorking = true
        errorMessage = nil

        Task {
            do {
                try await PrivilegedPowerControl.stop(using: password)
                endDate = nil
                defaults.removeObject(forKey: endDateKey)
                isSleepDisabled = false
            } catch {
                errorMessage = "未能恢复：\(error.localizedDescription)"
                refreshPowerState()
            }
            isWorking = false
        }
    }

    func refreshPowerState() {
        Task {
            do {
                let output = try await CommandRunner.output(executable: "/usr/bin/pmset", arguments: ["-g"])
                isSleepDisabled = output.range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil

                if !isSleepDisabled {
                    endDate = nil
                    defaults.removeObject(forKey: endDateKey)
                }
            } catch {
                errorMessage = "无法读取电源状态：\(error.localizedDescription)"
            }
        }
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
    private static let stateDirectory = "/var/db/LidAwake"
    private static let tokenPath = "\(stateDirectory)/timer-token"

    static func start(for seconds: Int, using password: String) async throws {
        let token = UUID().uuidString.lowercased()
        let delayedReset = "/bin/sleep \(seconds); if [ \"$(/bin/cat \(tokenPath) 2>/dev/null)\" = \(shellQuote(token)) ]; then /usr/bin/pmset -a disablesleep 0; /bin/rm -f \(tokenPath); fi"
        let setupCommand = "/bin/mkdir -p \(stateDirectory) && /bin/chmod 700 \(stateDirectory) && /bin/echo \(shellQuote(token)) > \(tokenPath) && /usr/bin/pmset -a disablesleep 1"

        try await CommandRunner.runSudo(command: setupCommand, password: password)
        do {
            try await CommandRunner.runSudoInBackground(command: delayedReset, password: password)
        } catch {
            try? await CommandRunner.runSudo(command: "/bin/rm -f \(tokenPath) && /usr/bin/pmset -a disablesleep 0", password: password)
            throw error
        }
    }

    static func stop(using password: String) async throws {
        let command = "/bin/rm -f \(tokenPath) && /usr/bin/pmset -a disablesleep 0"
        try await CommandRunner.runSudo(command: command, password: password)
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
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

@MainActor
private enum PasswordPrompt {
    static func request() -> String? {
        let alert = NSAlert()
        alert.messageText = "需要管理员密码"
        alert.informativeText = "请输入此 Mac 的登录密码以临时更改合盖睡眠设置。密码仅通过 sudo 的标准输入使用，不会被保存。"
        alert.addButton(withTitle: "继续")
        alert.addButton(withTitle: "取消")

        let passwordField = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        passwordField.placeholderString = "macOS 登录密码"
        alert.accessoryView = passwordField

        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        guard !passwordField.stringValue.isEmpty else { return nil }
        return passwordField.stringValue
    }
}

private enum CommandRunner {
    static func runSudo(command: String, password: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let inputPipe = Pipe()
                let outputPipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                process.arguments = ["-k", "-S", "-p", "", "/bin/sh", "-c", command]
                process.standardInput = inputPipe
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
                    inputPipe.fileHandleForWriting.write(Data((password + "\n").utf8))
                    try? inputPipe.fileHandleForWriting.close()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func runSudoInBackground(command: String, password: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let inputPipe = Pipe()
                let nullDevice = FileHandle(forWritingAtPath: "/dev/null")!

                process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                process.arguments = ["-k", "-S", "-p", "", "-b", "/bin/sh", "-c", command]
                process.standardInput = inputPipe
                process.standardOutput = nullDevice
                process.standardError = nullDevice

                process.terminationHandler = { process in
                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: CommandError(message: "无法启动定时恢复任务（sudo 退出码：\(process.terminationStatus)）。"))
                    }
                }

                do {
                    try process.run()
                    inputPipe.fileHandleForWriting.write(Data((password + "\n").utf8))
                    try? inputPipe.fileHandleForWriting.close()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
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

    var errorDescription: String? {
        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "系统命令执行失败。"
            : message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
