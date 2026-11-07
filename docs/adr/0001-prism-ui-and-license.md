# ADR 0001 · prism_ui 的采用与许可证影响

- 状态：待用户决策（记录当前实现方式）
- 日期：2026-11-07

## 背景

`prism_ui` 0.1.2 是本项目指定的视觉基础（超椭圆圆角、液态玻璃、弹簧动效、单色种子生成整套配色）。它采用 **GPL-3.0**。Flutter 把依赖编译进同一个可执行文件，通常认为分发产物即构成 GPL 意义上的衍生作品。

## 决策

1. 采用 `prism_ui: 0.1.2`，**精确锁版本**（不加 `^`）。
2. 所有对 `prism_ui` 的引用只允许出现在 `packages/docnest_ui`；该包在 `lib/docnest_ui.dart` 里统一再导出，业务代码只 import `docnest_ui`。
3. `tools/bin/check_imports.dart` 在 CI 中强制这条规则。

## 后果

- 自用或开源（GPL-3.0 兼容）可直接分发。
- 若项目要闭源或商用：需要作者另行授权，或只借鉴视觉风格、在 `docnest_ui` 内自建组件——由于隔离层的存在，替换范围被限制在一个包内。
- 由于 `PrismApp` 封装的是 `WidgetsApp`（没有 `routerConfig`），路由采用 Navigator 1.0，见 ADR 0005。
- 早期版本（0.1.x）API 可能变动：升级需要 ADR + golden 测试；需要修 bug 时 fork 到 `third_party/prism_ui` 并保留 LICENSE。
