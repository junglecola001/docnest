# ADR 0005 · Navigator 1.0 + 类型化路由表

- 状态：已采纳
- 日期：2026-11-07

## 背景

`PrismApp` 封装的是 `WidgetsApp`，没有 `routerConfig`，因此不能直接接 `go_router`（go_router 依赖 `Router`/`RouterDelegate`，需要 Material 或 `WidgetsApp.router` 家族的接线）。计划要求手机用卡片推入转场、桌面用淡入，且外部入口（Android 分享、通知、命令行参数）需要统一的页面寻址方式。

## 决策

1. 使用 Navigator 1.0：`PrismApp(onGenerateRoute: AppRoutes.onGenerateRoute, navigatorKey: rootNavigatorKey)`。
2. 路由用密封类描述数据，而不是字符串：
   ```dart
   sealed class AppRoute { Route<dynamic> toRoute(); }
   final class FolderRoute extends AppRoute { final RootId rootId; final String path; }
   final class PreviewRoute extends AppRoute { final DocId docId; }
   ```
   `AppNavigator.push(context, AppRoute.preview(docId))` 是唯一入口；内部调用 prism 的 `BaseNavigator.push`，由它按设备选择 `CardPageRoute` / `FadePageRoute`。
3. 每个一级入口（桌面侧栏项、手机 Dock 项）持有独立的嵌套 `Navigator`，用 `IndexedStack` 保留各自的页面栈。
4. 外部入口先转换成 `AppRoute`，再交给同一个入口分发，避免「深链一套、界面一套」。

## 后果

- 无法使用声明式路由的自动状态恢复；需要在各一级入口的 `Navigator` 上显式保存栈（M2 处理）。
- 类型化路由的值对象同时是 deep link 的解析目标，便于测试：`AppRoute.parse(uri)` / `AppRoute.toUri()`。
