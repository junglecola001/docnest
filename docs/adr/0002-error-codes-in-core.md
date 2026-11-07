# ADR 0002 · 错误码放在 docnest_core

- 状态：已采纳
- 日期：2026-11-07

## 背景

计划原本把错误码定义在 `docnest_protocol`，同时要求 `docnest_core` 的 `sealed class AppException` 与错误码一一对应。若协议依赖 core（DTO 需要 `DocKind` 等枚举），core 又要引用协议的 `ErrorCode`，就会形成循环依赖。

## 决策

- `DocNestErrorCode`（含 SCREAMING_SNAKE 的 `wire` 值）定义在 `docnest_core/lib/src/errors.dart`。
- `docnest_protocol` 依赖 `docnest_core`，在 `ApiErrorDto` 中只做编解码。
- 未知错误码不抛异常，降级为 `UnknownException`，保留原始字符串以便日志排查——协议向前兼容要求客户端忽略不认识的字段和值。

## 后果

- 依赖方向单向：core ← protocol ← host/remote/ui，没有循环。
- 新增错误码只需改一处，同时 `ApiErrorDto` 自动支持；`docs/protocol/openapi.yaml` 的枚举需同步（DoD 要求）。
