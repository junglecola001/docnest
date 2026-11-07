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

尚未实现的部分不会以空壳形式占位：`docnest_remote`、`docnest_win32` 会在对应里程碑落地时加入 workspace。

本地已验证：`dart test` 共 189 项（core / protocol / host，含 PathGuard 的 3000 例模糊测试与 Windows 联接点回归测试），`flutter test` 共 21 项（docnest_ui 16、app 5）。Windows 与 Android 的构建由 GitHub Actions 执行。

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
- `build-windows` / `build-android`：仅在 main、tag、手动触发时运行，产物上传为 artifact
- `release`：打 `v*` tag 时汇总产物并生成 Release Notes

## 许可证

待定。`prism_ui` 采用 GPL-3.0，分发方式决定后需要在 `docs/adr/0001-prism-ui-and-license.md` 记录结论。
