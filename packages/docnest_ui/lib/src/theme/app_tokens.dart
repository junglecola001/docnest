import 'package:docnest_core/docnest_core.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

/// DocNest's spacing steps.
///
/// Prism sets its components' internal rhythm; this is the scale DocNest lays
/// its own screens out on, so paddings between panels stay on 4 pt steps
/// instead of drifting to ad-hoc values per page.
abstract final class AppSpacing {
  /// 4 pt: the gap between a glyph and the text it labels.
  static const double xxs = 4;

  /// 8 pt: the gap between items inside one group.
  static const double xs = 8;

  /// 12 pt: the gap between a heading and its body.
  static const double sm = 12;

  /// 16 pt: the standard page inset.
  static const double md = 16;

  /// 20 pt: the gap between groups in a section.
  static const double lg = 20;

  /// 24 pt: the gap between sections.
  static const double xl = 24;

  /// 32 pt: the inset of an empty state.
  static const double xxl = 32;

  /// 40 pt: the largest gap a page uses before a hero area.
  static const double xxxl = 40;
}

/// The width at which DocNest stops presenting a single phone column.
abstract final class AppBreakpoints {
  /// Below this width the app hands out `isMobile: true` for [ViewScope].
  ///
  /// 600 dp is Material's compact/medium boundary and matches the narrowest
  /// window a Windows user can drag the host down to and still get two panes.
  static const double mobile = 600;
}

/// DocNest's corner radii.
///
/// Prism's own corner scale is 4/8/16/20/24/28; DocNest needs a 12 pt middle
/// step for dense rows, so only [sm] and [lg] come straight from prism's
/// `AppCorner` values.
abstract final class AppRadii {
  /// 8 pt: rows, chips and other small targets.
  static const double sm = 8;

  /// 12 pt: list rows and inputs, the step prism's scale skips.
  static const double md = 12;

  /// 20 pt: cards and sheets.
  static const double lg = 20;

  /// Prism's 8 pt radius, as a [BorderRadius].
  static const BorderRadius borderSm = AppRadius.sm;

  /// The 12 pt radius as a [BorderRadius].
  static const BorderRadius borderMd = BorderRadius.all(Radius.circular(md));

  /// Prism's 20 pt radius, as a [BorderRadius].
  static const BorderRadius borderLg = AppRadius.lg;

  /// Prism's 8 pt radius as the rounded-superellipse shape components draw.
  static const RoundedSuperellipseBorder shapeSm = AppShape.sm;

  /// The 12 pt radius as a rounded-superellipse shape.
  static const RoundedSuperellipseBorder shapeMd = RoundedSuperellipseBorder(
    borderRadius: borderMd,
  );

  /// Prism's 20 pt radius as the rounded-superellipse shape components draw.
  static const RoundedSuperellipseBorder shapeLg = AppShape.lg;
}

/// The colour DocNest paints a [DocKind]'s glyph and badge in.
///
/// Hues are fixed, so a PDF reads red wherever the user meets it and the type
/// stays recognisable without the label; only lightness follows [scheme], so
/// the same seven hues keep their contrast on a light or a dark surface.
///
/// Prism's colour helpers expose tone and relative tone shifts, neither of
/// which can pin a hue, so this composes the colour from HSL instead.
Color fileKindColor(DocKind kind, ColorScheme scheme) {
  final (hue, saturation) = switch (kind) {
    DocKind.pdf => (4.0, 0.72),
    DocKind.word => (214.0, 0.66),
    DocKind.spreadsheet => (142.0, 0.52),
    DocKind.presentation => (24.0, 0.82),
    DocKind.image => (190.0, 0.62),
    DocKind.text => (0.0, 0.0),
    DocKind.markdown => (270.0, 0.52),
    DocKind.ebook => (32.0, 0.42),
    DocKind.archive => (44.0, 0.36),
    DocKind.audio => (322.0, 0.52),
    DocKind.video => (348.0, 0.66),
    DocKind.other => (0.0, 0.0),
  };
  final lightness = scheme.brightness == Brightness.dark ? 0.68 : 0.44;
  return HSLColor.fromAHSL(1, hue, saturation, lightness).toColor();
}
