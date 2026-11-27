import 'package:flutter/material.dart';

import '../../../core/theme/app_palette.dart';

/// Colours for charts that have named categories (feelings, exercises,
/// thinking patterns). They are drawn as fills next to a text legend, so the
/// meaning never depends on colour alone.
List<Color> chartPalette(ColorScheme scheme) => [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      MoodColors.sky,
      MoodColors.sage,
      MoodColors.butter,
      MoodColors.rose,
      MoodColors.peach,
    ];

/// The colour of category [i]; goes round when there are more than eight.
Color chartColor(ColorScheme scheme, int i) {
  final p = chartPalette(scheme);
  return p[i % p.length];
}
