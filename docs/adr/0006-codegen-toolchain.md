# ADR 0006 · 代码生成工具链的版本约束

- 状态：已采纳
- 日期：2026-11-07

## 背景

`drift`、`freezed`、`riverpod_generator` 都依赖 `build_runner`，而 `build_runner` 依赖 `analyzer`。Flutter SDK 自带的 `flutter_test` 把 `matcher` / `test_api` 钉在特定版本上，进而把 `analyzer` 压到 `<14`。直接写最新的 `build_runner: ^2.17.1`（要求 `analyzer ^14.3.0`）会让整个 workspace 解析失败：

```text
Because docnest depends on flutter_test from sdk and docnest_core depends on test ^1.25.0,
analyzer >=8.0.0 <14.0.0 is required.
So, because docnest depends on build_runner ^2.17.1 which depends on analyzer ^14.3.0,
version solving failed.
```

## 决策

- 根 workspace 中把代码生成相关依赖写成**较宽的区间**，交给 pub 求解到与 Flutter SDK 兼容的最新组合：`build_runner: ^2.4.0`、`riverpod_generator: ^4.0.0`。
- 当前解析结果（记录在 `pubspec.lock`）：`build_runner 2.16.1`、`build 4.0.11`、`analyzer 13.3.0`、`riverpod_generator 4.0.10`、`flutter_riverpod 3.5.0`。
- 生成代码提交入库；CI 的 `codegen` job 重新生成并用 `git diff --exit-code` 检查是否最新。

## 后果

- 升级 Flutter 之前先看 `flutter_test` 钉住的 `analyzer` 上限，再决定 `build_runner` 能升到哪一版。
- 如果将来必须使用 `analyzer 14+`，需要把依赖代码生成的包从 workspace 里拆出去单独生成，或等 Flutter 抬高 `flutter_test` 的 `matcher` 上限。
- `dart pub get` 在 workspace 内需要 Flutter SDK（`sdk: flutter` 成员）；纯 Dart 包单独解析会失败，这是 ADR 0003 的已知代价。
