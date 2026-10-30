/// Non-color design tokens (NFR-41, SRS 5.3 and 5.4).
class AppTokens {
  static const fontFamily = 'Nunito';

  // Corner radii
  static const radiusSmall = 12.0;
  static const radiusCard = 24.0;
  static const radiusField = 16.0;
  static const radiusSheet = 28.0;
  static const radiusPill = 999.0;

  // Spacing
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space20 = 20.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  // Sizes
  static const minTouch = 48.0; // NFR-27
  static const iconSize = 24.0;
  static const bodySize = 16.0; // SRS 5.3

  /// Bottom padding for scroll views that sit under a floating button.
  static const fabClearance = 96.0;

  // Motion (SRS 5.4: 200 to 300 ms for UI, longer for reveals)
  static const motionFast = Duration(milliseconds: 200);
  static const motionNormal = Duration(milliseconds: 300);
  static const motionSlow = Duration(milliseconds: 700);
}
