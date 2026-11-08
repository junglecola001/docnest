# DocNest

本地优先的文档管理软件：Windows 端是宿主（扫描白名单文件夹、索引、预览、局域网服务），Android 端是遥控端（浏览、搜索、预览、互传）。数据只在局域网内流动，不依赖任何云服务。

完整设计见 [DocNest-开发计划.md](DocNest-开发计划.md)。技术决策记录见 [docs/adr](docs/adr)。

## 当前状态

| 模块 | 状态 |
|---|---|
| 单仓多包骨架 + CI | ✅ |
| `docnest_core` 领域模型、错误、仓库接口 | ✅ |
| `docnest_protocol` DTO / 路由 / 配对链接 / 事件 | ✅ |
| `docnest_host` PathGuard（含联接点与 TOCTOU）、文件名清洗、冲突命名、排除规则、断点续传状态机、扫描对账、搜索分词 | ✅ |
| `docnest_ui` 主题、tokens、prism_ui 中英文本地化、Material 桥接 | ✅ |
| `apps/docnest` 外壳、导航、设置（强调色 / 风格 / 主题 / 玻璃 / 字号） | ✅ |
| HTTPS 服务、配对、索引数据库（drift）、预览管道 | 待做（M2 起） |

尚未实现的部分不会以空壳形式占位：`docnest_win32` 会在 M1/M2 需要回收站、Shell 缩略图与 FileId 时加入 workspace。

本地已验证：`dart test` 共 212 项（core 22 / protocol 34 / host 152 / remote 4，含 PathGuard 的 3000 例模糊测试、Windows 联接点与 8.3 短名回归测试、真实 TLS 服务器上的证书固定测试），`flutter test` 共 21 项（docnest_ui 16、app 5）。Windows 与 Android 的构建由 GitHub Actions 执行。

## 环境

- Flutter **3.47.9**（`.fvmrc`，`prism_ui` 要求 ≥ 3.47）
- Windows 10 22H2 / 11；Android 10+（minSdk 29）
- Windows 构建需要 Visual Studio 2022 的「使用 C++ 的桌面开发」工作负载

## 常用命令

```bash
flutter pub get          # workspace 统一解析
dart test packages/docnest_core
dart test packages/docnest_protocol
dart test packages/docnest_host
dart test packages/docnest_remote
flutter test packages/docnest_ui
flutter test apps/docnest
dart run tools/bin/check_imports.dart
files=$(git ls-files '*.dart' | grep -vE '\.(g|freezed)\.dart$')
dart format --output=none --set-exit-if-changed $files
flutter analyze --fatal-infos
```

`melos run <script>` 提供同样的入口（见 `melos.yaml`）。

## 目录

```text
apps/docnest/           Flutter 应用（windows + android）
packages/docnest_core/  纯 Dart 领域层：模型、错误、仓库接口
packages/docnest_protocol/ 纯 Dart 协议层：DTO、路由、事件、配对链接
packages/docnest_host/  宿主核心：PathGuard、扫描、上传、搜索（纯 Dart，可 dart test）
packages/docnest_remote/ 客户端核心：证书固定（发现与传输队列属于 M2/M3）
packages/docnest_ui/    prism_ui 隔离层：主题、tokens、本地化、桥接
tools/                  仓库脚本（import 规则检查）
docs/adr/               架构决策记录
```

## CI

`/.github/workflows/ci.yml`：

- `check`（ubuntu）：format（跳过生成代码）、analyze、import 规则
- `codegen`（ubuntu）：`flutter gen-l10n` + `build_runner`，要求 `git diff` 为空
- `test-dart`（ubuntu）：core / protocol / host 单元测试
- `test-windows`（windows）：host 测试，覆盖联接点与 Windows 路径语义
- `test-flutter`（ubuntu）：docnest_ui、app 组件测试
- `build-windows` / `build-android`：仅在 main、tag、手动触发时运行，产物上传为 artifact。Android 目前沿用模板的 debug keystore 签名，正式发布前需要在 Secrets 中配置签名密钥。
- `release`：打 `v*` tag 时汇总产物并生成 Release Notes

## 下载与运行

[Releases](https://github.com/junglecola001/docnest/releases) 页面提供 CI 构建的产物：

| 平台 | 文件 | 用法 |
|---|---|---|
| Windows 10/11 x64 | `docnest-windows-x64.zip` | 解压后直接运行 `docnest.exe`（免安装；x64 版本在 ARM64 Windows 上由系统模拟运行） |
| Android 10+ | `app-arm64-v8a-release.apk` 等 | 按机型 ABI 安装；目前用 debug 证书签名，安装时需允许「未知来源」 |

当前版本（0.1.0）是 M0 外壳：资料库 / 搜索 / 传输 是诚实的空状态，**设置页可用**（强调色、配色风格、浅色/深色、液态玻璃、字号），改完立刻生效。

## 许可证

GPL-3.0（见 [LICENSE](LICENSE)）。原因：界面基础 `prism_ui` 采用 GPL-3.0，而 Flutter 会把依赖编译进同一个可执行文件，分发产物因此需要以 GPL-3.0 兼容的方式提供源码。若要闭源或商用，需要取得 prism_ui 作者授权，或只借鉴视觉风格、在 `docnest_ui` 内自建组件（隔离层已为此预留）。详见 `docs/adr/0001-prism-ui-and-license.md`。
