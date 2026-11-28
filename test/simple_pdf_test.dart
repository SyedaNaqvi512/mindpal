import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindpal/features/insights/models/pdf_fonts.dart';
import 'package:mindpal/features/insights/models/simple_pdf.dart';

/// Checks the file is a well-formed PDF: header, an xref table whose offsets
/// each point at "N 0 obj", the trailer and the end marker.
void expectWellFormed(String s, {int? pages}) {
  expect(s.startsWith('%PDF-1.4'), isTrue);
  expect(s.trimRight().endsWith('%%EOF'), isTrue);
  final start = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(s)!.group(1)!);
  expect(s.substring(start).startsWith('xref\n'), isTrue);
  final lines = s.substring(start).split('\n');
  final count = int.parse(lines[1].split(' ')[1]);
  expect(lines[2], '0000000000 65535 f ');
  for (var i = 1; i < count; i++) {
    final offset = int.parse(lines[2 + i].substring(0, 10));
    expect(s.substring(offset).startsWith('$i 0 obj'), isTrue, reason: 'object $i');
  }
  expect(s.contains('/Size $count'), isTrue);
  if (pages != null) {
    expect(s.contains('/Count $pages'), isTrue);
    expect(RegExp(r'/Type /Page /Parent').allMatches(s).length, pages);
  }
}

void main() {
  test('a one-page file is well formed and carries the text', () {
    final pdf = SimplePdf();
    pdf.bigTitle('MindPal summary');
    pdf.paragraph('Hello world');
    pdf.bullet('A bullet');
    pdf.barRow('Good', 0.5, '3 (50%)');
    pdf.rule();
    final s = latin1.decode(pdf.build(created: DateTime(2026, 11, 27, 10, 5, 9)));
    expectWellFormed(s, pages: 1);
    expect(s, contains('(Hello world) Tj'));
    expect(s, contains('D:20261127100509'));
    expect(s, contains('page 1 of 1'));
  });

  test('long content flows onto more pages, each with a footer', () {
    final pdf = SimplePdf();
    for (var i = 0; i < 120; i++) {
      pdf.bullet('Line number $i with a few words so that it takes some room');
    }
    expect(pdf.pageCount, greaterThan(1));
    final s = latin1.decode(pdf.build());
    expectWellFormed(s, pages: pdf.pageCount);
    expect(s, contains('page ${pdf.pageCount} of ${pdf.pageCount}'));
  });

  test('long paragraphs wrap inside the page width', () {
    final pdf = SimplePdf();
    pdf.paragraph('word ' * 200);
    final s = latin1.decode(pdf.build());
    expect(RegExp(r'\) Tj').allMatches(s).length, greaterThan(5));
    expectWellFormed(s);
  });

  test('brackets and backslashes are escaped, emoji are replaced', () {
    expect(SimplePdf.clean('a \u{1F600} b'), 'a ? b');
    expect(SimplePdf.clean('it’s “ok” – fine…'), 'it\'s "ok" - fine...');
    final pdf = SimplePdf()..paragraph(r'a (b) \ c');
    final s = latin1.decode(pdf.build());
    expect(s, contains(r'(a \(b\) \\ c) Tj'));
    expectWellFormed(s);
  });

  test('an empty document still builds', () {
    final s = latin1.decode(SimplePdf().build());
    expectWellFormed(s, pages: 1);
  });

  test('bars never draw outside their track for odd fractions', () {
    final pdf = SimplePdf()
      ..barRow('x', double.nan, '0')
      ..barRow('y', 5, '9')
      ..barRow('z', -2, '0');
    expectWellFormed(latin1.decode(pdf.build()));
  });

  group('logo and fonts', () {
    PdfFontSet realFonts() {
      Uint8List read(String f) => File('assets/fonts/$f').readAsBytesSync();
      return PdfFontSet(
        body: PdfEmbeddedFont(kNunitoRegularMetrics, read('Nunito-Regular.ttf')),
        bold: PdfEmbeddedFont(kNunitoBoldMetrics, read('Nunito-Bold.ttf')),
        display: PdfEmbeddedFont(kFrauncesBoldMetrics, read('Fraunces-Bold.ttf')),
      );
    }

    test('the brand header draws the logo as vector curves with a gradient', () {
      final pdf = SimplePdf()..brandHeader('MindPal summary', 'Last 30 days');
      final s = latin1.decode(pdf.build());
      expectWellFormed(s, pages: 1);
      expect(s, contains('/ShadingType 2'));
      expect(s, contains('/Sh1 sh'));
      expect(s, contains('(MindPal summary) Tj'));
      expect(s, contains('(Last 30 days) Tj'));
      expect(RegExp(r' c\n').allMatches(s).length, greaterThan(100));
    });

    test('the logo can be drawn more than once, each with its own gradient', () {
      final pdf = SimplePdf()
        ..logo(48, 800, 40)
        ..logo(120, 800, 20);
      final s = latin1.decode(pdf.build());
      expectWellFormed(s, pages: 1);
      expect(s, contains('/Sh1 sh'));
      expect(s, contains('/Sh2 sh'));
      expect(s, contains('/Sh2 '));
    });

    test('embedded fonts are written with widths, a descriptor and the file', () {
      final pdf = SimplePdf(fonts: realFonts())
        ..brandHeader('MindPal summary', 'Last 30 days')
        ..heading('At a glance')
        ..paragraph('Calm and steady days: caf\u00e9, na\u00efve.');
      final s = latin1.decode(pdf.build());
      expectWellFormed(s, pages: 1);
      expect(s, contains('/Subtype /TrueType'));
      expect(s, contains('/BaseFont /Nunito-Regular'));
      expect(s, contains('/BaseFont /Nunito-Bold'));
      expect(s, contains('/BaseFont /Fraunces-Bold'));
      expect(RegExp(r'/FontFile2 \d+ 0 R').allMatches(s).length, 3);
      expect(RegExp(r'/FirstChar 32 /LastChar 255').allMatches(s).length, 3);
      expect(s, contains('/Filter /FlateDecode'));
      expect(s, contains('/F3 '));
    });

    test('the font tables hold 224 widths and text is measured with them', () {
      for (final m in [kNunitoRegularMetrics, kNunitoBoldMetrics, kFrauncesBoldMetrics]) {
        expect(m.widths.length, 224);
        expect(m.widths[0], greaterThan(0)); // the space
        expect(m.width('Hello', 10), greaterThan(0));
      }
      final pdf = SimplePdf(fonts: realFonts());
      expect(pdf.measure('Hello', 11), kNunitoRegularMetrics.width('Hello', 11));
      expect(pdf.measure('iiii', 12), lessThan(pdf.measure('MMMM', 12)));
      // an emoji counts like the question mark that replaces it
      expect(pdf.measure('\u{1F600}', 12), pdf.measure('?', 12));
    });

    test('long text still wraps inside the page with embedded fonts', () {
      final pdf = SimplePdf(fonts: realFonts())..paragraph('word ' * 300);
      final s = latin1.decode(pdf.build());
      expect(RegExp(r'\) Tj').allMatches(s).length, greaterThan(5));
      expectWellFormed(s);
    });

    test('control characters from 0x80 to 0x9F are dropped', () {
      expect(SimplePdf.clean('a\u0085b\u009fc'), 'abc');
      expect(SimplePdf.clean('caf\u00e9'), 'caf\u00e9');
    });
  });
}
