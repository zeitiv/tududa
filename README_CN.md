<div align="center">

# 📱 Tududa

<img src="assets/icon.png" width="128" alt="Tududa Icon">
<br>
<small><em>应用图标由 AI 生成</em></small>

**基于 [Tududi](https://github.com/chrisvel/tududi) 的 Flutter 移动客户端**

*一个平静、开放的生活与工作组织系统。*

[![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?logo=dart)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Vibe Coded](https://img.shields.io/badge/Vibe-Coded_🎵-ff69b4)](#-vibe-coding)

[English](README.md) | **中文**

</div>

---

## ⚠️ 声明

**本项目是第三方移动客户端。** Tududa 与原始 Tududi 项目没有任何隶属、背书或关联关系。

原始 [Tududi](https://github.com/chrisvel/tududi) 由 **[Chris Veleris](https://github.com/chrisvel)** 创建并维护 —— 一个基于 Node.js 和 React 构建的自托管任务管理系统。所有后端 API 和服务端逻辑均属于原始项目，采用 [MIT 许可证](https://github.com/chrisvel/tududi/blob/main/LICENSE) 开源。

本 Flutter 客户端是一个独立的、社区驱动的项目，旨在将 Tududi 体验带到移动设备上。

---

## 🎵 Vibe Coding

本项目完全采用 **Vibe Coding** 方式构建 —— 通过人与 AI 的对话式结对编程完成。没有任何代码是以传统方式手动逐行编写的；相反，每一个功能、修复和设计决策都诞生于与 AI 编程助手的自然语言对话中。

> *"描述你想要的，让代码自然流淌。"*

---

## ✨ 功能特性

- 📋 **任务** — 创建、编辑、删除和完成任务，支持优先级、截止日期、重复任务（含重复规则编辑器）和子任务（排序暂未持久化）
- ⚡ **快速添加** — 支持英文、德文和中文的自然语言输入（如“明天下午 5 点买牛奶，每周”），也可从 Android 小组件使用
- 📅 **今天、专注与每日回顾**，以及智能列表（即将到来、已逾期、将来某天、已完成）
- 👆 **任务条目** — 滑动操作、批量选择、撤销和行内编辑
- 🔎 **全局搜索**（带离线回退）和**命令面板**（Ctrl/Cmd+K）
- 📁 **项目** — 将任务分组到项目中；项目任务和全局任务列表均提供看板视图
- 🗂️ **领域与标签** — 用领域（Area）组织项目，用标签标记内容
- 📝 **笔记** — 支持 Markdown 格式的笔记，可关联到项目
- 📥 **收件箱** — 快速记录
- 📴 **离线优先** — 无网络也能使用，更改会在后台同步（见[下文](#-离线优先行为)）
- 🧭 **五个标签页的主界面**（今天、收件箱、即将到来、项目、更多），宽屏上使用导航栏，并支持 `tududa://` 深链接
- 🧩 **Android 桌面小组件**，基于 Glance 和 Material You（见[下文](#-android-小组件)）
- 🌐 **英文、德文和中文**界面，也可跟随系统语言
- 🎨 **Material Design 3**，支持浅色和深色主题、Material You 动态取色、内置 Inter 字体，以及对比度、密度和减少动画设置
- ♿ **无障碍**测试套件
- 🔐 **会话认证** — 对接自托管 Tududi 服务器

---

## 🛠️ 技术栈

| 类别 | 技术 |
|---|---|
| **框架** | Flutter 3.47.7 / Dart 3.13 |
| **状态管理** | Riverpod |
| **本地存储** | Drift (SQLite)，配合发件箱（outbox）与同步引擎 |
| **网络** | Dio + Cookie Jar，自定义拦截器 |
| **路由** | GoRouter |
| **Android 原生** | Kotlin 库 `:tududi_core`（基于 Tink 的加密保险库、API 客户端）；`:app` 中的 Glance 小组件、快速添加 Activity 和 Flutter 桥接 |
| **本地化** | Flutter `gen-l10n`，ARB 片段由 `tool/merge_arb.dart` 合并 |
| **测试** | `flutter_test`、无障碍与性能测试、alchemist 截图测试（仅 CI）、Kotlin 单元测试与仪器测试 |

---

## 🧰 工具链

工具链已固定，保证本地与 CI 构建一致：

- **Flutter 3.47.7**，固定在 `pubspec.yaml` 的 `environment.flutter`。CI 通过 `flutter-version-file` 读取，SDK 版本不一致时会失败。
- Android 构建使用 **JDK 17**。
- Dart 依赖由已提交的 `pubspec.lock` 锁定；CI 使用 `flutter pub get --enforce-lockfile` 安装。
- 由于 Dart 3.13 工具链的限制，`flutter_riverpod`、`go_router`、`drift`、`drift_dev`、`freezed` 暂不升级大版本。

---

## 🚀 构建、运行与测试

```bash
git clone https://github.com/zeitiv/tududa.git
cd tududa

flutter pub get
# 生成的代码（Drift、freezed、json_serializable）不提交到仓库：
dart run build_runner build -d

flutter run                  # 在设备或模拟器上运行
flutter test --concurrency=6 # Dart 测试（截图测试仅在 CI 运行，见下文）
flutter analyze --fatal-infos

# 本地化（见“本地化与主题”）
dart run tool/merge_arb.dart --check   # lib/l10n/src 中的片段与 lib/l10n/arb 一致
flutter gen-l10n                       # 重新生成 lib/l10n/gen

# 共享 Android 核心库与 app 模块的 Kotlin 单元测试
cd android && ./gradlew :tududi_core:testDebugUnitTest :app:testDebugUnitTest

# 真机/模拟器测试（需连接设备）
flutter test integration_test/widget_bridge_test.dart
cd android && ./gradlew :app:connectedDebugAndroidTest
```

在登录界面输入 Tududi 服务器地址（例如 `http://your-server:3002`）及账号信息。

构建 APK：

```bash
flutter build apk --release
```

没有 `android/key.properties` 时，release 构建使用 debug 密钥签名（仅适合本地测试）。正式发布包只在 CI 中签名。

### 截图（Golden）测试

截图测试位于 `test/goldens`，带有 `golden` 标签。只有 CI 截图（alchemist，Ahem 字体），因此在不同机器上结果确定；平台截图已禁用。本地日常运行时可以跳过：

```bash
flutter test --exclude-tags golden             # 跳过截图测试
flutter test --tags golden test/goldens        # 对比
bash tool/ci/golden_update.sh                    # 重新生成（--update-goldens），检查后提交图片
```

CI 会运行完整测试集，包括截图测试。

### 本地化与主题

- 界面文案以 JSON 片段形式编写在 `lib/l10n/src/*.json`，并合并到 `lib/l10n/arb`（英文、德文、中文）。`flutter gen-l10n` 的输出已提交在 `lib/l10n/gen`。
- **新增文案：** 在 `lib/l10n/src` 的某个片段中添加键（三种语言都要有），运行 `dart run tool/merge_arb.dart`，再运行 `flutter gen-l10n`，然后提交结果。如果 `merge_arb.dart --check` 或 `flutter gen-l10n` 之后的 `git diff -- lib/l10n` 发现差异，CI 会失败。
- 语言在设置中选择（英文、德文、中文或跟随系统）。外观设置包括主题、动态取色、对比度、密度和减少动画。设计令牌位于 `lib/core/design`。

---

## 🏗️ 架构

离线优先、分层设计。界面不会直接访问网络。

```
widgets -> Riverpod providers -> 离线 repository -> Drift 表 + outbox
                                                         ^
                               SyncEngine -> sync handlers -> Dio 栈 -> Tududi 服务器
```

| 层 | 位置 |
|---|---|
| API 客户端、DTO、拦截器 | `lib/core/api` |
| Drift 数据库、DAO、脏字段追踪、搜索索引 | `lib/core/db` |
| 同步引擎、handler、outbox、字段级合并 | `lib/core/sync` |
| 会话、凭据存储、静默重新登录 | `lib/auth/session` |
| 功能模块（`tasks`、`projects`、`areas`、`tags`、`notes`、`inbox`、`search`、`settings`、`auth`） | `lib/<feature>`，含 `data`、`domain`、`providers`、`screens` |
| 路由、主界面、深链接 | `lib/core/router` |
| 设计令牌、主题、字体 | `lib/core/design` |
| 本地化（片段、ARB、生成代码） | `lib/l10n` |
| 原生桥接的 Flutter 端 | `lib/core/platform` |
| 共享 Android 核心（保险库、API 客户端、看板缓存） | `android/tududi_core` |
| Android 小组件、快速添加 Activity、桥接 | `android/app`（通道约定：`android/CHANNELS.md`） |

数据流图与写入/合并流程见 [docs/architecture.md](docs/architecture.md)。

---

## 🔧 服务器兼容性

基于 Tududi **v1.9.4** 开发。主要的 API 特点：

- 修改类请求（`POST`、`PATCH`、`DELETE`）需要 CSRF 请求头 `x-csrf-token`。客户端从 `GET /csrf-token` 获取令牌，被服务器拒绝时会刷新一次。
- 登出使用 `GET /api/logout`。
- 领域（Area）接口使用复数形式 `/api/areas`。
- 更新使用 `PATCH`（而非 `PUT`），资源以 `uid` 字符串标识。
- 会话基于 Cookie；遇到 401 时，客户端使用保存的凭据静默重新登录。

---

## 📴 离线优先行为

- 所有读取来自本地数据库；所有写入在同一个事务中写入本地数据库和 outbox。
- 同步引擎在设备联网时（以及手动同步时）先拉取更改，再推送待处理条目。推送失败会退避重试；多次失败后条目被标记为卡住，需要手动重试。
- 冲突按字段合并：本地修改过的字段保留本地值，除非服务器也修改了同一字段。被服务器拒绝的更改会回滚并通知你。删除和完成操作与其他更改一样排队。
- 同步状态指示会显示待处理、卡住和失败的更改。

---

## 🧩 Android 小组件

桌面小组件（Glance，Material You 配色）显示你今天的任务。

- **工作方式。** 小组件是原生实现，绘制时不运行 Flutter。它从共享的 `:tududi_core` 库读取看板，该库自己与服务器通信并保留一份小缓存。有网络时约每 30 分钟刷新一次，另外在午夜、系统时间变化以及你添加任务之后刷新。在小组件中完成任务会发送到服务器；服务器确认后，应用中的**小组件对账器（reconciler）**通过小组件桥接把它应用到本地数据库。
- **快速添加弹窗。** 小组件上的“+”会打开一个透明 Activity，承载同一个 Flutter 快速添加面板（自然语言解析、重复规则）。点击小组件的其他区域会通过 `tududa://today` 打开应用。
- **登录与保险库。** 登录时，应用通过 `tududa/session` 通道把凭据交给原生端，原生端将其保存在 Tink 加密的保险库中。小组件与应用共用该保险库，小组件用它静默登录。如果你从没有保险库的旧版本升级，需要重新登录一次，凭据才会被存入保险库。
- **安全模型。** 凭据、Cookie、看板缓存和变更日志只保存在加密保险库中；登出会清空保险库。凭据不会被写入日志或 `BuildConfig`。Flutter 与原生代码之间的约定见 [android/CHANNELS.md](android/CHANNELS.md)。

---

## 🔐 安全模型

- 凭据只保存在由 Android Keystore 支持的加密保险库中，绝不出现在源码、`BuildConfig` 或日志里。
- 调试日志经过脱敏（凭据、Cookie 和 CSRF 令牌被遮蔽）。
- 使用明文 `http://` 服务器时，需要在配置服务器时显式允许。
- 签名密钥只作为 CI Secrets 存在；发布工作流把它们写到工作区之外，并在构建后删除。发布的 APK 附带 SHA-256 校验文件。
- CI 会执行密钥泄露扫描（gitleaks）和依赖漏洞扫描（OSV）。

---

## 🗺️ 路线图

尚未实现：

- iOS
- CI 中的仪器测试（已接入模拟器任务，尚未验证）
- 子任务排序持久化
- 独立的标签页面

已知限制：服务器不支持按年重复；截图测试仅在 CI 运行。

已完成的内容见 [CHANGELOG.md](CHANGELOG.md)。

---

## 🤝 参与贡献

欢迎为本客户端贡献代码：请提交 issue 或 Pull Request。提交前请运行 `dart format`、`flutter analyze --fatal-infos` 和 `flutter test --concurrency=6`（修改过文案的话还要运行 `dart run tool/merge_arb.dart --check` 和 `flutter gen-l10n`），并在 `CHANGELOG.md` 的 *Unreleased* 下补充一行。

对于 **Tududi 后端**，请遵守上游规则：新功能的 Pull Request 需要事先有 issue 或讨论。参见[上游贡献指南](https://github.com/chrisvel/tududi/blob/main/.github/CONTRIBUTING.md)。

---

## 📜 许可证

本项目采用 [MIT 许可证](LICENSE)。

---

## 🙏 致谢

- **[Chris Veleris](https://github.com/chrisvel)** — 原始 [Tududi](https://github.com/chrisvel/tududi) 项目的创建者。没有他出色的开源工作，就不会有这个客户端。
- **[Tududi 社区](https://github.com/chrisvel/tududi/discussions)** — 感谢构建和维护服务端生态。
- 使用 ❤️ 和 **Vibe Coding** 🎵 的力量，基于 [Flutter](https://flutter.dev) 构建。

---

<div align="center">

*Tududa — 让生活与工作的组织变得平静而有序*

</div>
