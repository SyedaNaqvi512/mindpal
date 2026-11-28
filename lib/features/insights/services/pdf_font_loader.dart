import 'package:flutter/services.dart';

import '../models/pdf_fonts.dart';

/// Loads the fonts of the PDF summary (Nunito for text, Fraunces for the title
/// and headings) from the app's own font files. If anything goes wrong it
/// returns null and the summary is made with the standard fonts instead, so
/// creating the PDF never fails because of a font.
Future<PdfFontSet?> loadPdfFonts({AssetBundle? bundle}) async {
  try {
    final b = bundle ?? rootBundle;
    Future<PdfEmbeddedFont> load(String file, PdfFontMetrics metrics) async {
      final data = await b.load('assets/fonts/$file');
      return PdfEmbeddedFont(
          metrics, data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    }

    return PdfFontSet(
      body: await load('Nunito-Regular.ttf', kNunitoRegularMetrics),
      bold: await load('Nunito-Bold.ttf', kNunitoBoldMetrics),
      display: await load('Fraunces-Bold.ttf', kFrauncesBoldMetrics),
    );
  } catch (_) {
    return null;
  }
}
