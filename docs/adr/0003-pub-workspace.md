# ADR 0003 · Dart pub workspace 单仓多包

- 状态：已采纳
- 日期：2026-11-07

## 决策

使用 Dart pub workspace（根 `pubspec.yaml` 的 `workspace:`）统一解析依赖，每个成员声明 `resolution: workspace`；`melos.yaml` 只提供脚本入口，不参与依赖解析（`usePubspecOverrides: false`）。

## 理由

- 一份 `pubspec.lock`、一个 `.dart_tool`，`flutter pub get` 一次即可，CI 缓存更有效。
- 成员之间用 `path:` 依赖，改动立即生效，不需要 `melos bootstrap` 生成 override。
- workspace 要求所有成员同时可解析：因此尚未实现的包（`docnest_remote`、`docnest_win32`）**不进入 workspace**，避免空壳包。

## 后果

- 无法单独解析某个纯 Dart 包（根工作区包含 Flutter 应用，需要 Flutter SDK）。`dart test packages/docnest_host` 在 workspace 内依然可用。
- 新增包时同时更新根 `workspace:` 列表与 `melos.yaml` 的 `packages` glob。
