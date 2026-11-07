# AGENTS.md

给接续开发的人（和 AI）的现状说明。设计意图见 `DocNest-开发计划.md`，决策见 `docs/adr/`。

## 已实现

| 包 | 内容 | 验证方式 |
|---|---|---|
| `docnest_core` | `Root` / `DocEntry` / `DocDetail` / `FolderEntry` / `Tag` / `TrashTicket`、`DocQuery` / `PageOf`、`LibraryEvent`、`DocNestErrorCode` + `sealed AppException`、`LibraryRepository` 接口 | `dart test packages/docnest_core` |
| `docnest_protocol` | `ApiPaths` / `ApiHeaders`、`HostInfoDto`、`RootDto`、`DocDto` / `ChildrenPageDto`、上传 DTO、配对 DTO、`EventDto`、`ApiErrorDto`、`PairingLink` | `dart test packages/docnest_protocol` |
| `docnest_host` | `PathGuard`（含 TOCTOU 复核、重解析点检查）、`NameSanitizer`、`ConflictResolver`、`ExcludeGlobs`、`IoPathProbe`、断点续传状态机、扫描/对账、搜索分词与语法 | `dart test packages/docnest_host` |
| `docnest_ui` | prism_ui 隔离层：`AppTheme`、tokens、`DocNestUiLocalizations`、`MaterialBridge`、`AsyncView`、`DocNestAppRoot` | `flutter test packages/docnest_ui` |
| `apps/docnest` | 外壳、导航、外观设置（强调色 / 风格 / 玻璃 / 深色模式） | `flutter test apps/docnest` |

## 尚未实现（按里程碑）

- M1：drift 数据库与索引、文件监听、缩略图、预览（pdfrx）、托盘与单实例。
- M2：证书生成、HTTPS/WS 服务、二维码配对、UDP 发现、`docnest_remote` 的发现与传输队列（证书固定已完成）。
- M3：真实传输（把 `docnest_host` 的上传状态机接到 HTTP）、前台服务、分享入口。

`docnest_win32` 尚未加入 workspace：等它真有回收站、Shell 缩略图、FileId 等 FFI 内容时再加，避免空壳包。`docnest_remote` 目前只有证书固定（`createPinnedHttpClient` / `certificateFingerprint`），有真实 TLS 服务器测试。

## 运行与验证

```bash
flutter pub get
dart test packages/docnest_core packages/docnest_protocol packages/docnest_host   # 逐个跑亦可
flutter test packages/docnest_ui
flutter test apps/docnest
dart run tools/bin/check_imports.dart
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
```

CI（`.github/workflows/ci.yml`）跑同一组命令；Windows/Android 构建只在 main、tag 和手动触发时执行。

## 修改代码时的硬约束

1. **路径**：任何文件系统访问都必须从 `PathGuard.resolve` 拿到 `ResolvedPath`；远程接口只接受 `(rootId, 相对路径)`。
2. **写入**：临时文件 + 原子重命名；删除走两段式回收站。当前 `docnest_host` 的上传状态机已经把「落盘」与「提交」分开（`Mover` 回调），接线时不要绕过。
3. **依赖方向**：core ← protocol ← host/remote/ui；UI 只 import `docnest_ui`（它再导出 prism_ui）。
4. **错误**：跨层只抛 `AppException` 子类；未知错误包成 `UnknownException`，界面只显示错误编号。
5. **可测试性**：宿主核心保持纯 Dart（可 `dart test`）；平台差异通过接口注入（`PathProbe`、`ChunkSink`、`Mover`）。
6. **生成代码**：`*.g.dart` / `*.freezed.dart` 提交入库，且保持生成器原样输出——`dart format` 检查会跳过它们（CI 的 `codegen` job 重新生成后要求 `git diff` 为空）。
7. **Flutter 组件测试里的点击**：`flutter test` 不会编译依赖包的 shader，prism 的按压火花会报 `packages/prism_ui/shaders/…` 缺失。`apps/docnest/test` 用 `_ignorePrismShaderAssetError()` 精确忽略这一条，不要扩大范围。

## 已知待确认

- 许可证（prism_ui 是 GPL-3.0）：见 ADR 0001，需要决定开源 / 自用 / 闭源。
- Office 预览是否依赖本机 Office/WPS/LibreOffice。
- 配对时「删除」权限默认是否勾选。
