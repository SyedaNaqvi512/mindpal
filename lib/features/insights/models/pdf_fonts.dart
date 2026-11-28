// Measurements of the fonts that are embedded in the PDF summary (Nunito and
// Fraunces, both SIL Open Font License, see assets/fonts). Widths are in
// 1/1000 em for the characters 32 to 255 of the Windows ANSI set, so text is
// measured exactly and lines wrap where they should. Generated from the font
// files; the font programs themselves are loaded from the app assets.
import 'dart:typed_data';

class PdfFontMetrics {
  const PdfFontMetrics({
    required this.name,
    required this.widths,
    required this.ascent,
    required this.descent,
    required this.capHeight,
    required this.bbox,
  });

  /// The PostScript name used inside the PDF (no spaces).
  final String name;

  /// Advance widths for the codes 32..255.
  final List<int> widths;
  final int ascent;
  final int descent;
  final int capHeight;
  final List<int> bbox;

  /// Width of [s] at [size] points. Characters outside 32..255 count as a
  /// question mark, which is what the writer prints for them.
  double width(String s, double size) {
    var sum = 0;
    for (final r in s.runes) {
      final code = (r >= 32 && r <= 255) ? r : 63;
      sum += widths[code - 32];
    }
    return sum * size / 1000;
  }
}

/// A font ready to embed: its measurements and the TrueType file.
class PdfEmbeddedFont {
  const PdfEmbeddedFont(this.metrics, this.data);

  final PdfFontMetrics metrics;
  final Uint8List data;
}

/// The three fonts of the summary: body text, bold text and the display face
/// used for the title and headings.
class PdfFontSet {
  const PdfFontSet({required this.body, required this.bold, required this.display});

  final PdfEmbeddedFont body;
  final PdfEmbeddedFont bold;
  final PdfEmbeddedFont display;
}

const PdfFontMetrics kNunitoRegularMetrics = PdfFontMetrics(
  name: 'Nunito-Regular',
  ascent: 1011,
  descent: -353,
  capHeight: 705,
  bbox: [-392, -277, 1301, 1047],
  widths: [
    258, 228, 392, 600, 600, 930, 693, 221, 317, 317, 450, 600, 228, 424, 228, 283,
    600, 600, 600, 600, 600, 600, 600, 600, 600, 600, 228, 228, 600, 600, 600, 443,
    946, 729, 676, 673, 742, 583, 548, 726, 761, 257, 324, 625, 543, 855, 740, 767,
    633, 767, 669, 615, 602, 728, 689, 1101, 650, 596, 589, 315, 283, 315, 600, 500,
    356, 530, 583, 463, 583, 532, 333, 586, 568, 232, 236, 500, 296, 856, 568, 556,
    583, 583, 358, 481, 350, 561, 515, 841, 525, 514, 463, 352, 265, 352, 600, 500,
    600, 0, 228, 600, 394, 686, 324, 324, 472, 1327, 615, 260, 1046, 0, 589, 0,
    0, 228, 228, 394, 394, 524, 500, 1000, 555, 925, 481, 260, 910, 0, 463, 596,
    258, 228, 600, 600, 600, 600, 265, 545, 467, 815, 327, 441, 600, 424, 815, 501,
    371, 600, 380, 380, 356, 600, 588, 228, 402, 380, 339, 441, 893, 937, 893, 443,
    729, 729, 729, 729, 729, 729, 981, 673, 583, 583, 583, 583, 257, 257, 257, 257,
    742, 740, 767, 767, 767, 767, 767, 600, 767, 728, 728, 728, 728, 596, 634, 615,
    530, 530, 530, 530, 530, 530, 861, 463, 532, 532, 532, 532, 232, 232, 232, 232,
    560, 568, 556, 556, 556, 556, 556, 600, 556, 561, 561, 561, 561, 514, 583, 514,
  ],
);

const PdfFontMetrics kNunitoBoldMetrics = PdfFontMetrics(
  name: 'Nunito-Bold',
  ascent: 1011,
  descent: -353,
  capHeight: 705,
  bbox: [-403, -278, 1339, 1055],
  widths: [
    271, 248, 448, 600, 600, 945, 726, 243, 358, 358, 453, 600, 248, 434, 248, 313,
    600, 600, 600, 600, 600, 600, 600, 600, 600, 600, 248, 248, 600, 600, 600, 459,
    950, 744, 688, 680, 762, 597, 562, 736, 773, 282, 354, 665, 562, 868, 748, 785,
    652, 785, 686, 631, 621, 738, 713, 1113, 672, 618, 605, 354, 313, 354, 600, 500,
    377, 547, 600, 472, 600, 542, 364, 604, 585, 255, 259, 536, 319, 877, 585, 576,
    600, 600, 392, 488, 384, 579, 527, 853, 546, 526, 474, 391, 288, 391, 600, 500,
    600, 0, 248, 600, 443, 745, 345, 345, 494, 1344, 631, 287, 1056, 0, 605, 0,
    0, 248, 248, 443, 443, 524, 500, 1000, 582, 954, 488, 287, 915, 0, 474, 618,
    271, 248, 600, 600, 600, 600, 288, 570, 512, 815, 339, 494, 600, 434, 815, 525,
    379, 600, 380, 380, 377, 600, 624, 248, 421, 380, 353, 494, 912, 960, 912, 459,
    744, 744, 744, 744, 744, 744, 993, 680, 597, 597, 597, 597, 282, 282, 282, 282,
    762, 748, 785, 785, 785, 785, 785, 600, 785, 738, 738, 738, 738, 618, 655, 653,
    547, 547, 547, 547, 547, 547, 865, 472, 542, 542, 542, 542, 255, 255, 255, 255,
    581, 585, 576, 576, 576, 576, 576, 600, 576, 579, 579, 579, 579, 526, 600, 526,
  ],
);

const PdfFontMetrics kFrauncesBoldMetrics = PdfFontMetrics(
  name: 'Fraunces-Bold',
  ascent: 978,
  descent: -255,
  capHeight: 700,
  bbox: [-46, -288, 1436, 1120],
  widths: [
    206, 326, 411, 672, 616, 848, 984, 198, 374, 374, 614, 570, 303, 392, 292, 488,
    694, 480, 634, 585, 654, 602, 639, 552, 645, 641, 294, 306, 526, 570, 526, 566,
    954, 762, 734, 706, 810, 675, 632, 770, 865, 426, 546, 818, 646, 958, 776, 793,
    722, 793, 781, 625, 716, 762, 745, 1094, 744, 704, 649, 363, 488, 370, 490, 504,
    260, 568, 617, 528, 627, 536, 418, 585, 648, 326, 325, 626, 327, 961, 648, 596,
    631, 616, 494, 504, 409, 637, 566, 859, 576, 580, 513, 410, 300, 410, 646, 500,
    722, 0, 265, 500, 520, 956, 556, 556, 374, 1072, 625, 352, 1040, 0, 649, 0,
    0, 258, 256, 510, 516, 439, 548, 863, 366, 1076, 504, 352, 900, 0, 513, 704,
    206, 304, 528, 654, 592, 700, 331, 604, 436, 920, 532, 617, 574, 392, 733, 394,
    397, 572, 386, 360, 255, 647, 704, 304, 292, 309, 534, 617, 818, 834, 854, 542,
    762, 762, 762, 762, 762, 762, 1014, 706, 675, 675, 675, 675, 426, 426, 426, 426,
    810, 776, 793, 793, 793, 793, 793, 546, 793, 762, 762, 762, 762, 704, 736, 728,
    568, 568, 568, 568, 568, 568, 830, 528, 536, 536, 536, 536, 324, 324, 324, 324,
    596, 648, 596, 596, 596, 596, 596, 570, 594, 637, 637, 637, 637, 580, 618, 580,
  ],
);
