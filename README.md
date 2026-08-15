# 别睡

一个原生 macOS 小工具：让 MacBook 在合盖后继续运行指定时间，适合等待下载、脚本、编译或远程任务完成。

![平台](https://img.shields.io/badge/platform-macOS%2014%2B-000000?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-6.0%2B-F05138?logo=swift&logoColor=white)

## 功能

- 合盖后继续运行：通过 `pmset -a disablesleep 1` 临时阻止合盖睡眠。
- 预设时长：1、2、4、8 小时；也支持自定义时长，最长 24 小时。
- 自动恢复：到期自动执行 `pmset -a disablesleep 0`，恢复原有合盖睡眠行为。
- 手动停止：随时点击“立即恢复合盖休眠”。
- 状态与倒计时：显示当前是否已启用，以及预计恢复时间。
- 原生应用图标、检查更新入口和退出确认。

## 使用前须知

> [!WARNING]
> 合盖持续运行会产生热量。请连接电源、将电脑放在通风且坚硬的表面上；**不要将合盖运行的电脑放进背包或密闭空间**。

- 首次开始或手动恢复时，需要输入 macOS 管理员密码。
- 密码仅通过 `sudo` 的标准输入传递给系统命令；应用不会保存或写入密码。
- 若手动中断应用，防睡眠设置可能仍在生效。可在终端恢复：

  ```zsh
  sudo pmset -a disablesleep 0
  ```

## 构建与运行

### 要求

- macOS 14 或更高版本
- Xcode，或已安装 Swift 工具链

### 生成 `.app`

```zsh
cd 别睡
./Scripts/build-app.zsh
```

构建完成后的应用位于：

```text
dist/别睡.app
```

双击该 `.app` 后，选择持续时间并点击“开始保持运行”。

### 开发模式

```zsh
swift run
```

## 项目结构

```text
Assets/                     应用图标资源
Scripts/build-app.zsh       构建并打包 macOS 应用
Scripts/generate-icon.swift 生成图标 PNG 的辅助脚本
Sources/LidAwake/           SwiftUI 应用源码
Package.swift               Swift Package 配置
```

## 工作原理

1. 应用以管理员权限执行 `pmset -a disablesleep 1`。
2. 同时启动独立的后台定时任务。
3. 到期后，后台任务执行 `pmset -a disablesleep 0`。
4. 如果用户手动恢复，应用会取消当前定时标识并立即恢复合盖睡眠。

## 许可证

暂未指定许可证。若你准备公开复用或接受贡献，建议在发布前补充适合的 `LICENSE` 文件。
