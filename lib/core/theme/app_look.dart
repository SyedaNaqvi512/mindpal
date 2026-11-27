import 'package:flutter/material.dart';

/// How cards are drawn.
enum CardStyle {
  /// Round and raised, with a soft coloured shadow.
  soft,

  /// Square-ish with a thin ink outline and no shadow, like a printed page.
  paper,

  /// Flat, with a fine hairline and no shadow.
  flat,

  /// Dark with a faint glowing edge.
  glow,
}

/// The pattern drawn behind every screen.
enum BackdropStyle { blobs, paper, plain, stars }

/// The shape of the bottom navigation bar.
enum NavStyle {
  /// A rounded bar that floats above the bottom edge, with a round add button.
  floating,

  /// A flat bar with a ruled top edge and a tab that fills in, like notebook tabs.
  tabs,

  /// A flat bar with a thin line above the chosen item.
  line,

  /// A dark bar with a soft glow under the chosen item.
  glow,
}

/// The drawing style of illustrations, headers and empty states.
enum ArtStyle { blobs, lines, dots, stars }

/// How things move.
enum MotionStyle {
  /// Springy: things bounce a little as they arrive.
  bouncy,

  /// Calm: slow, even fades, like turning a page.
  gentle,

  /// Quick and exact: short fades, almost no travel.
  crisp,

  /// Slow and floating: long fades and a drifting glow.
  dreamy,
}

/// One complete look for the app: the shape of cards and controls, the fonts,
/// the background, the illustrations, the navigation and the way things move.
/// A look goes with a colour palette (see [AppLook.forPalette]).
class AppLook {
  const AppLook({
    required this.id,
    required this.name,
    required this.tagline,
    required this.displayFamily,
    required this.bodyFamily,
    required this.cardStyle,
    required this.cardRadius,
    required this.fieldRadius,
    required this.buttonRadius,
    required this.sheetRadius,
    required this.headerRadius,
    required this.backdrop,
    required this.nav,
    required this.art,
    required this.motion,
    this.displayScale = 1.0,
    this.bodyLineHeight = 1.5,
    this.centerTitles = false,
    this.gradientHeader = true,
  });

  final String id;
  final String name;
  final String tagline;

  /// Titles and headings.
  final String displayFamily;

  /// Body text, buttons and labels.
  final String bodyFamily;

  /// Titles in some typefaces look smaller at the same size; this evens it out.
  final double displayScale;
  final double bodyLineHeight;

  final CardStyle cardStyle;
  final double cardRadius;
  final double fieldRadius;

  /// Null means a pill (fully round ends).
  final double? buttonRadius;
  final double sheetRadius;
  final double headerRadius;
  final BackdropStyle backdrop;
  final NavStyle nav;
  final ArtStyle art;
  final MotionStyle motion;
  final bool centerTitles;

  /// False gives a flat, single-colour header with a straight bottom edge.
  final bool gradientHeader;

  OutlinedBorder get buttonShape => buttonRadius == null
      ? const StadiumBorder()
      : RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius!));

  // ---- Motion, in one place so every animation follows the look ----

  /// Multiplies animation lengths.
  double get durationScale => switch (motion) {
        MotionStyle.bouncy => 1.0,
        MotionStyle.gentle => 1.2,
        MotionStyle.crisp => 0.7,
        MotionStyle.dreamy => 1.6,
      };

  /// Multiplies how far things slide in.
  double get slideScale => switch (motion) {
        MotionStyle.bouncy => 1.0,
        MotionStyle.gentle => 0.6,
        MotionStyle.crisp => 0.35,
        MotionStyle.dreamy => 0.5,
      };

  /// The curve for things that grow into place.
  Curve get popCurve => switch (motion) {
        MotionStyle.bouncy => Curves.elasticOut,
        MotionStyle.gentle => Curves.easeOutBack,
        MotionStyle.crisp => Curves.easeOutCubic,
        MotionStyle.dreamy => Curves.easeOutQuart,
      };

  /// The curve for things that fade and slide in.
  Curve get enterCurve => switch (motion) {
        MotionStyle.bouncy => Curves.easeOutCubic,
        MotionStyle.gentle => Curves.easeInOutCubic,
        MotionStyle.crisp => Curves.easeOut,
        MotionStyle.dreamy => Curves.easeInOutSine,
      };

  /// How small a pressed card gets.
  double get pressScale => switch (motion) {
        MotionStyle.bouncy => 0.97,
        MotionStyle.gentle => 0.98,
        MotionStyle.crisp => 0.99,
        MotionStyle.dreamy => 0.975,
      };

  /// Multiplies how far floating shapes travel (crisp barely moves).
  double get floatScale => switch (motion) {
        MotionStyle.bouncy => 1.0,
        MotionStyle.gentle => 0.7,
        MotionStyle.crisp => 0.3,
        MotionStyle.dreamy => 1.5,
      };

  /// Multiplies how long a floating loop takes (bigger is slower).
  double get periodScale => switch (motion) {
        MotionStyle.bouncy => 1.0,
        MotionStyle.gentle => 1.3,
        MotionStyle.crisp => 1.0,
        MotionStyle.dreamy => 1.7,
      };

  Duration scaled(Duration d) =>
      Duration(milliseconds: (d.inMilliseconds * durationScale).round());

  // ---- The four looks ----

  static const soft = AppLook(
    id: 'soft',
    name: 'Soft & Rounded',
    tagline: 'Round shapes, gentle colour and a playful bounce',
    displayFamily: 'Fraunces',
    bodyFamily: 'Nunito',
    cardStyle: CardStyle.soft,
    cardRadius: 28,
    fieldRadius: 18,
    buttonRadius: null,
    sheetRadius: 32,
    headerRadius: 36,
    backdrop: BackdropStyle.blobs,
    nav: NavStyle.floating,
    art: ArtStyle.blobs,
    motion: MotionStyle.bouncy,
  );

  static const paper = AppLook(
    id: 'paper',
    name: 'Paper Journal',
    tagline: 'Ink on paper, like a printed notebook',
    displayFamily: 'Playfair Display',
    bodyFamily: 'Lora',
    cardStyle: CardStyle.paper,
    cardRadius: 6,
    fieldRadius: 6,
    buttonRadius: 8,
    sheetRadius: 10,
    headerRadius: 6,
    backdrop: BackdropStyle.paper,
    nav: NavStyle.tabs,
    art: ArtStyle.lines,
    motion: MotionStyle.gentle,
    displayScale: 0.95,
    bodyLineHeight: 1.55,
    centerTitles: true,
  );

  static const minimal = AppLook(
    id: 'minimal',
    name: 'Clean & Minimal',
    tagline: 'Flat, light and precise, with quick movements',
    displayFamily: 'Manrope',
    bodyFamily: 'Manrope',
    cardStyle: CardStyle.flat,
    cardRadius: 4,
    fieldRadius: 4,
    buttonRadius: 4,
    sheetRadius: 10,
    headerRadius: 0,
    backdrop: BackdropStyle.plain,
    nav: NavStyle.line,
    art: ArtStyle.dots,
    motion: MotionStyle.crisp,
    bodyLineHeight: 1.5,
    gradientHeader: false,
  );

  static const night = AppLook(
    id: 'night',
    name: 'Night Glow',
    tagline: 'A calm dark sky with a soft glow and slow drifting',
    displayFamily: 'Cormorant Garamond',
    bodyFamily: 'Nunito',
    cardStyle: CardStyle.glow,
    cardRadius: 22,
    fieldRadius: 14,
    buttonRadius: null,
    sheetRadius: 28,
    headerRadius: 28,
    backdrop: BackdropStyle.stars,
    nav: NavStyle.glow,
    art: ArtStyle.stars,
    motion: MotionStyle.dreamy,
    displayScale: 1.14,
  );

  static const all = [soft, paper, minimal, night];

  /// The look that goes with a palette id (see AppPalette).
  static AppLook forPalette(String paletteId) => switch (paletteId) {
        'roseCream' => paper,
        'skyMist' => minimal,
        'midnightLavender' => night,
        _ => soft,
      };

  /// The look of the current theme. Falls back to Soft & Rounded when a test
  /// builds a plain theme.
  static AppLook of(BuildContext context) =>
      Theme.of(context).extension<AppLookExtension>()?.look ?? soft;
}

/// Carries the look inside `ThemeData`, so any widget can read it.
class AppLookExtension extends ThemeExtension<AppLookExtension> {
  const AppLookExtension(this.look);

  final AppLook look;

  @override
  AppLookExtension copyWith({AppLook? look}) => AppLookExtension(look ?? this.look);

  @override
  AppLookExtension lerp(ThemeExtension<AppLookExtension>? other, double t) =>
      t < 0.5 || other is! AppLookExtension ? this : other;
}
