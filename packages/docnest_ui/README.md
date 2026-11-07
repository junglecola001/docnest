# docnest_ui

DocNest's shared UI layer, built on [`prism_ui`](https://pub.dev/packages/prism_ui) 0.1.2.

Application code imports one library, `package:docnest_ui/docnest_ui.dart`, and
never `package:prism_ui` or `package:flutter/material.dart` directly; both rules
are enforced by `tools/bin/check_imports.dart`.

## What it holds

| Path | Purpose |
| --- | --- |
| `lib/src/theme/app_theme.dart` | `AppTheme.light` / `AppTheme.dark`: prism `ThemeData` on a seed, with the CJK font fallbacks DocNest titles need. |
| `lib/src/theme/app_tokens.dart` | Spacing, radii and breakpoints, plus `fileKindColor` — the fixed-hue colour of each `DocKind`. |
| `lib/src/l10n/docnest_ui_localizations.dart` | `DocNestUiLocalizations`: every string prism's components ask for, in Chinese and English. |
| `lib/src/app/docnest_app_root.dart` | `DocNestAppRoot`: a `PrismApp` with the required delegates and a `ViewScope` published above the routes. |
| `lib/src/bridge/material_bridge.dart` | `MaterialBridge`: the only file allowed to import Material, wrapping pdfrx and markdown subtrees in a Material theme derived from prism's. |
| `lib/src/components/async_view.dart` | `AsyncView<T>`: skeleton, failure-with-retry and data states for a riverpod `AsyncValue`. |
| `lib/src/icons/app_glyphs.dart` | `AppGlyphs`: the destinations and file kinds prism does not ship (Lucide path data, ISC). |

## Rules

* No Material import outside `lib/src/bridge/`.
* Every public member carries an English doc comment; comments explain the
  invariant (atomicity, security, why a value is what it is), not the mechanics.
* Prism names (`ThemeData`, `ThemeMode`, `ColorScheme`, `Switch`, ...) shadow
  Material's by design: the app uses prism's and the bridge prefixes Material's.

## Tests

```
flutter test
```
