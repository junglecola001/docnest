# 贡献指南

精简版规范，完整版见 `DocNest-开发计划.md` 第 6 节。CI 会强制执行其中可自动检查的部分。

## 分支与提交

- GitHub Flow：`main` 受保护；分支 `feat/…`、`fix/…`、`refactor/…`、`docs/…`、`chore/…`。
- Conventional Commits，例如 `feat(transfer): 上传支持断点续传`。
- PR 必须 CI 通过，squash 合并。

## 完成标准（DoD）

- `dart format` 无改动，`flutter analyze --fatal-infos` 零告警，`dart run tools/bin/check_imports.dart` 通过。
- 新增行为有测试；修复缺陷有回归测试。
- 新文案进入 ARB。
- 涉及协议时同一提交内更新 `docs/protocol/openapi.yaml` 与 `docnest_protocol`。
- 重大决策补写 ADR。

## 依赖规则（CI 强制）

1. 只有 `docnest_ui` 可以 import `package:prism_ui`。
2. 界面层不 import `package:flutter/material.dart`，桥接组件除外（`docnest_ui/lib/src/bridge/`）。
3. `docnest_core`、`docnest_protocol` 是纯 Dart：不 import Flutter，不 import `dart:io`。
4. `domain` 层不 import `data` 层。
5. 业务代码不出现 `Platform.isXxx`，平台分支只在组合根。

## 文件安全红线（违反即 P0 缺陷）

1. 所有路径都经过 `PathGuard`；远程接口只接受 `(rootId, 相对路径)`。
2. 删除只进回收站（两段式），任何代码路径都不允许永久删除用户文件。
3. 写入一律「临时文件 + 原子重命名」，失败清理临时文件。
4. 不修改文档内容。
5. 只读根目录拒绝一切写操作；云盘占位文件默认不读取内容。
6. 所有远程写操作写审计日志。
