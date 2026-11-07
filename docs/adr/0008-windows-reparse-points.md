# ADR 0008 · Windows 重解析点探测与 8.3 短名

- 状态：已采纳
- 日期：2026-11-07

## 背景

`PathGuard` 需要回答两个只能向操作系统求证的问题：

1. 路径链上是否有联接点 / 符号链接（默认拒绝，除非根目录允许跟随）；
2. 打开句柄后真实路径是否仍在根目录内（防 TOCTOU）。

最初的 `IoPathProbe` 只用 `dart:io`：把 `resolveSymbolicLinksSync` 的结果与给定路径比较，不一致就认为是重解析点。在本地（`C:\Users\HUAWEI\...`）一切正常，在 GitHub Actions 的 Windows runner 上却把所有普通目录都判成了联接点——因为那里的 TEMP 位于 `C:\Users\RUNNER~1\AppData\Local\Temp`，**8.3 短名**让规范化路径与给定路径天然不同，与链接无关。

## 决策

1. 重解析点用 `GetFileAttributesW` 的 `FILE_ATTRIBUTE_REPARSE_POINT` 位判断（`dart:ffi` 直接查 `kernel32`，不引入插件，也不依赖 `docnest_win32`）。
   - `FileSystemEntity.typeSync(..., followLinks: false) == link` 仍是符号链接的快路径；
   - 只在 Windows 上调用 FFI；非 Windows 返回 `false`。
2. 规范化路径只用于**包含性判断**，绝不用于推断「这是不是链接」。
3. 包含性比较同时接受两种根目录形式：配置时的形态与它自己的规范化形态。这样 8.3 短名、`subst` 盘符、网络映射都不会造成误判。
4. 回归测试固化这两点：
   - `path_guard_junction_test.dart` 用 `mklink /J` 建真实联接点，并另外验证「8.3 短名不是联接点」；
   - `path_guard_test.dart` 用 FakeProbe 模拟 `RUNNER~1` 根目录与长名真实路径。

## 后果

- 本地复现 CI 条件的方法：把 `TMP`/`TEMP` 指向一个短名目录（`...\LONGDI~1`）再跑 `dart test packages/docnest_host`。两种布局下 152 项测试都必须通过。
- `tools/bin/check_imports.dart` 允许 `io_path_probe.dart` 出现 `Platform.isWindows`：它是注入接口的平台实现，不是业务分支。
- 如果将来需要在宿主里区分「目录联接」与「文件符号链接」以支持不同的策略，同一处 FFI 扩展即可，不需要改 `PathGuard`。
