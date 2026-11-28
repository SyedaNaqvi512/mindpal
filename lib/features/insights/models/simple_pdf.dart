import 'dart:convert';
import 'dart:io' show zlib;
import 'dart:typed_data';

import 'pdf_fonts.dart';
import 'pdf_logo.dart';

/// A colour for the PDF, 0 to 255 for each part.
class PdfRgb {
  const PdfRgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;

  String get _fill => '${(r / 255).toStringAsFixed(3)} ${(g / 255).toStringAsFixed(3)} '
      '${(b / 255).toStringAsFixed(3)}';
}

const PdfRgb kPdfInk = PdfRgb(33, 33, 43);
const PdfRgb kPdfMuted = PdfRgb(98, 98, 112);
const PdfRgb kPdfAccent = PdfRgb(98, 76, 168);
const PdfRgb kPdfTrack = PdfRgb(232, 230, 240);

enum PdfFace { body, bold, display }

/// A small, dependency-free PDF writer for the Insights summary: A4 pages with
/// text, bars, rules and the MindPal logo (drawn as vector curves). It writes
/// plain PDF 1.4. With a [PdfFontSet] the text uses embedded TrueType fonts
/// (Nunito and Fraunces); without one it uses Helvetica, which every PDF reader
/// has. Text is limited to the Latin characters of the Windows ANSI set: other
/// characters (emoji, for example) are replaced, so nothing breaks.
class SimplePdf {
  SimplePdf({this.title = 'MindPal summary', this.fonts}) {
    _newPage();
  }

  final String title;
  final PdfFontSet? fonts;
  final List<String> _shadings = [];

  static const double pageW = 595.28, pageH = 841.89, margin = 48;
  static const double _footerRoom = 36;

  final List<StringBuffer> _pages = [];
  double _y = pageH - margin;

  int get pageCount => _pages.length;
  double get contentWidth => pageW - 2 * margin;

  void _newPage() {
    _pages.add(StringBuffer());
    _y = pageH - margin;
  }

  void _need(double h) {
    if (_y - h < margin + _footerRoom) _newPage();
  }

  StringBuffer get _out => _pages.last;

  /// Replaces anything the built-in font cannot show.
  static String clean(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      switch (r) {
        case 0x2018:
        case 0x2019:
          b.write("'");
        case 0x201C:
        case 0x201D:
          b.write('"');
        case 0x2013:
        case 0x2014:
          b.write('-');
        case 0x2026:
          b.write('...');
        case 0x0A:
        case 0x0D:
        case 0x09:
          b.write(' ');
        default:
          if ((r >= 0x20 && r < 0x7F) || (r >= 0xA0 && r <= 0xFF)) {
            b.writeCharCode(r);
          } else if (r > 0xFF) {
            b.write('?');
          }
      }
    }
    return b.toString();
  }

  static String _escape(String s) =>
      clean(s).replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

  /// An estimate of the width of [s] in points, for Helvetica. It averages
  /// about half an em per character.
  static double textWidth(String s, double size, {bool bold = false}) =>
      clean(s).length * size * (bold ? 0.55 : 0.52);

  PdfEmbeddedFont? _embedded(PdfFace face) {
    final f = fonts;
    if (f == null) return null;
    switch (face) {
      case PdfFace.body:
        return f.body;
      case PdfFace.bold:
        return f.bold;
      case PdfFace.display:
        return f.display;
    }
  }

  /// The width of [s] in the font that will be used for [face].
  double measure(String s, double size, {PdfFace face = PdfFace.body}) {
    final e = _embedded(face);
    final c = clean(s);
    if (e == null) return textWidth(c, size, bold: face != PdfFace.body);
    return e.metrics.width(c, size);
  }

  List<String> _wrap(String text, double size, double width, {PdfFace face = PdfFace.body}) {
    final words = clean(text).split(' ').where((w) => w.isNotEmpty);
    final lines = <String>[];
    var line = '';
    for (final w in words) {
      final candidate = line.isEmpty ? w : '$line $w';
      if (measure(candidate, size, face: face) <= width || line.isEmpty) {
        line = candidate;
      } else {
        lines.add(line);
        line = w;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  static String _key(PdfFace face) {
    switch (face) {
      case PdfFace.body:
        return 'F1';
      case PdfFace.bold:
        return 'F2';
      case PdfFace.display:
        return 'F3';
    }
  }

  void _text(String s, double x, double y, double size,
      {PdfFace face = PdfFace.body, PdfRgb color = kPdfInk}) {
    _out.write('BT ${color._fill} rg /${_key(face)} ${size.toStringAsFixed(1)} Tf '
        '${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} Td (${_escape(s)}) Tj ET\n');
  }

  void _rect(double x, double y, double w, double h, PdfRgb color) {
    if (w <= 0 || h <= 0) return;
    _out.write('${color._fill} rg ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} '
        '${w.toStringAsFixed(2)} ${h.toStringAsFixed(2)} re f\n');
  }

  void space(double h) => _y -= h;

  void heading(String s, {double size = 15}) {
    _need(size * 2.4);
    space(size * 0.9);
    _y -= size;
    _text(s, margin, _y, size, face: PdfFace.display, color: kPdfAccent);
    space(4);
    _rect(margin, _y, contentWidth, 0.6, kPdfTrack);
    space(2);
  }

  void bigTitle(String s) {
    _y -= 26;
    _text(s, margin, _y, 24, face: PdfFace.display);
    space(6);
  }

  /// The top of the first page: the MindPal logo, the [title] in the display
  /// face, a [subtitle] line and a thin accent rule.
  void brandHeader(String title, String subtitle) {
    const logoSize = 48.0;
    _need(logoSize + 24);
    final top = _y;
    logo(margin, top, logoSize);
    const textX = margin + logoSize + 14;
    _text(title, textX, top - 21, 24, face: PdfFace.display);
    _text(subtitle, textX, top - 40, 10.5, color: kPdfMuted);
    _y = top - logoSize;
    space(12);
    _rect(margin, _y, contentWidth, 1.6, kPdfAccent);
    space(8);
  }

  /// Draws the logo with its top-left corner at ([x], [top]), [size] points
  /// wide. It is the same drawing as the logo in the app: a gradient tile, a
  /// warm dot, a leaf and the cursive "m".
  void logo(double x, double top, double size) {
    final s = size;
    final bottom = top - s;
    final r = 0.28 * s;
    final kr = 0.5523 * r;
    String n(double v) => v.toStringAsFixed(2);
    double px(double u) => x + u * s;
    double py(double v) => bottom + (1 - v) * s;
    String col(List<int> c) =>
        PdfRgb(c[0], c[1], c[2])._fill;
    String arr(List<int> c) =>
        '${(c[0] / 255).toStringAsFixed(3)} ${(c[1] / 255).toStringAsFixed(3)} ${(c[2] / 255).toStringAsFixed(3)}';

    final shNo = _shadings.length + 1;
    _shadings.add('<< /ShadingType 2 /ColorSpace /DeviceRGB '
        '/Coords [${n(x)} ${n(top)} ${n(x + s)} ${n(bottom)}] '
        '/Function << /FunctionType 2 /Domain [0 1] /C0 [${arr(kLogoGradientFrom)}] '
        '/C1 [${arr(kLogoGradientTo)}] /N 1 >> /Extend [true true] >>');

    final o = _out;
    o.write('q\n');
    o.write('${n(x + r)} ${n(bottom)} m ${n(x + s - r)} ${n(bottom)} l\n');
    o.write('${n(x + s - r + kr)} ${n(bottom)} ${n(x + s)} ${n(bottom + r - kr)} ${n(x + s)} ${n(bottom + r)} c\n');
    o.write('${n(x + s)} ${n(top - r)} l\n');
    o.write('${n(x + s)} ${n(top - r + kr)} ${n(x + s - r + kr)} ${n(top)} ${n(x + s - r)} ${n(top)} c\n');
    o.write('${n(x + r)} ${n(top)} l\n');
    o.write('${n(x + r - kr)} ${n(top)} ${n(x)} ${n(top - r + kr)} ${n(x)} ${n(top - r)} c\n');
    o.write('${n(x)} ${n(bottom + r)} l\n');
    o.write('${n(x)} ${n(bottom + r - kr)} ${n(x + r - kr)} ${n(bottom)} ${n(x + r)} ${n(bottom)} c\n');
    o.write('h W n /Sh$shNo sh\nQ\n');

    // warm dot
    final cx = px(0.725), cy = py(0.249), dr = 0.065 * s, dk = 0.5523 * dr;
    o.write('${col(kLogoDotColor)} rg ${n(cx + dr)} ${n(cy)} m '
        '${n(cx + dr)} ${n(cy + dk)} ${n(cx + dk)} ${n(cy + dr)} ${n(cx)} ${n(cy + dr)} c '
        '${n(cx - dk)} ${n(cy + dr)} ${n(cx - dr)} ${n(cy + dk)} ${n(cx - dr)} ${n(cy)} c '
        '${n(cx - dr)} ${n(cy - dk)} ${n(cx - dk)} ${n(cy - dr)} ${n(cx)} ${n(cy - dr)} c '
        '${n(cx + dk)} ${n(cy - dr)} ${n(cx + dr)} ${n(cy - dk)} ${n(cx + dr)} ${n(cy)} c f\n');

    // leaf, with its veins
    _smoothPath(kLogoLeaf, px, py, col(kLogoLeafColor));
    final veins = '${arr(kLogoVeinColor)} RG ${(0.006 * s < 0.3 ? 0.3 : 0.006 * s).toStringAsFixed(2)} w 1 J\n'
        '${n(px(0.673))} ${n(py(0.683))} m ${n(px(0.757))} ${n(py(0.488))} l S\n'
        '${n(px(0.708))} ${n(py(0.586))} m ${n(px(0.690))} ${n(py(0.549))} l S\n'
        '${n(px(0.717))} ${n(py(0.581))} m ${n(px(0.781))} ${n(py(0.552))} l S\n';
    o.write(veins);

    // the letter on top
    _smoothPath(kLogoLetter, px, py, col(kLogoLetterColor));
  }

  /// Writes a closed, smooth outline through [p] (x, y pairs in the unit
  /// square) and fills it. The same curve as LogoPainter: quadratic curves
  /// between the middles of neighbouring points, written as cubic curves.
  void _smoothPath(List<double> p, double Function(double) px, double Function(double) py, String fill) {
    final n = p.length ~/ 2;
    double ux(int i) => p[(i % n) * 2];
    double uy(int i) => p[(i % n) * 2 + 1];
    String f(double v) => v.toStringAsFixed(2);
    var x0 = px((ux(n - 1) + ux(0)) / 2);
    var y0 = py((uy(n - 1) + uy(0)) / 2);
    final b = StringBuffer('$fill rg ${f(x0)} ${f(y0)} m\n');
    for (var i = 0; i < n; i++) {
      final cx = px(ux(i)), cy = py(uy(i));
      final ex = px((ux(i) + ux(i + 1)) / 2), ey = py((uy(i) + uy(i + 1)) / 2);
      b.write('${f(x0 + 2 / 3 * (cx - x0))} ${f(y0 + 2 / 3 * (cy - y0))} '
          '${f(ex + 2 / 3 * (cx - ex))} ${f(ey + 2 / 3 * (cy - ey))} ${f(ex)} ${f(ey)} c\n');
      x0 = ex;
      y0 = ey;
    }
    b.write('h f\n');
    _out.write(b.toString());
  }

  void paragraph(String s, {double size = 11, bool bold = false, PdfRgb color = kPdfInk, double indent = 0}) {
    final face = bold ? PdfFace.bold : PdfFace.body;
    final lines = _wrap(s, size, contentWidth - indent, face: face);
    for (final l in lines) {
      _need(size * 1.5);
      _y -= size * 1.4;
      _text(l, margin + indent, _y, size, face: face, color: color);
    }
    space(3);
  }

  void bullet(String s, {double size = 11}) {
    final lines = _wrap(s, size, contentWidth - 16);
    for (var i = 0; i < lines.length; i++) {
      _need(size * 1.5);
      _y -= size * 1.4;
      if (i == 0) _rect(margin + 3, _y + size * 0.3, 3.5, 3.5, kPdfAccent);
      _text(lines[i], margin + 14, _y, size);
    }
    space(2);
  }

  /// A label on the left, a bar in the middle ([fraction] 0 to 1) and the
  /// value in words on the right.
  void barRow(String label, double fraction, String value, {PdfRgb color = kPdfAccent}) {
    const h = 16.0;
    _need(h + 4);
    _y -= h;
    const labelW = 150.0, valueW = 110.0;
    _text(label, margin, _y + 3, 10.5);
    final barX = margin + labelW;
    final barW = contentWidth - labelW - valueW;
    _rect(barX, _y, barW, 9, kPdfTrack);
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0).toDouble();
    _rect(barX, _y, barW * f, 9, color);
    _text(value, barX + barW + 8, _y + 1, 10, color: kPdfMuted);
    space(5);
  }

  /// A thin line across the page.
  void rule() {
    _need(10);
    space(4);
    _rect(margin, _y, contentWidth, 0.7, kPdfTrack);
    space(6);
  }

  static Uint8List _ascii(String s) => Uint8List.fromList(latin1.encode(s));

  static Uint8List _streamObject(String extra, List<int> data) {
    final b = BytesBuilder()
      ..add(_ascii('<< /Length ${data.length}${extra.isEmpty ? '' : ' $extra'} >>\nstream\n'))
      ..add(data)
      ..add(_ascii('\nendstream'));
    return b.toBytes();
  }

  /// The finished file.
  Uint8List build({DateTime? created}) {
    final total = _pages.length;
    final c = created ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final date = 'D:${c.year}${two(c.month)}${two(c.day)}${two(c.hour)}${two(c.minute)}${two(c.second)}';

    final objects = <Uint8List>[];
    int add(Uint8List b) {
      objects.add(b);
      return objects.length;
    }

    add(_ascii('')); // 1: catalog, filled in below
    add(_ascii('')); // 2: pages, filled in below

    int addFont(PdfEmbeddedFont? f, String builtIn) {
      if (f == null) {
        return add(_ascii('<< /Type /Font /Subtype /Type1 /BaseFont /$builtIn '
            '/Encoding /WinAnsiEncoding >>'));
      }
      final m = f.metrics;
      final fileNo = add(_streamObject(
          '/Length1 ${f.data.length} /Filter /FlateDecode', zlib.encode(f.data)));
      final descNo = add(_ascii('<< /Type /FontDescriptor /FontName /${m.name} /Flags 32 '
          '/FontBBox [${m.bbox.join(' ')}] /ItalicAngle 0 /Ascent ${m.ascent} '
          '/Descent ${m.descent} /CapHeight ${m.capHeight} /StemV 80 '
          '/FontFile2 $fileNo 0 R >>'));
      return add(_ascii('<< /Type /Font /Subtype /TrueType /BaseFont /${m.name} '
          '/FirstChar 32 /LastChar 255 /Widths [${m.widths.join(' ')}] '
          '/FontDescriptor $descNo 0 R /Encoding /WinAnsiEncoding >>'));
    }

    final f1 = addFont(fonts?.body, 'Helvetica');
    final f2 = addFont(fonts?.bold, 'Helvetica-Bold');
    final f3 = addFont(fonts?.display, 'Helvetica-Bold');
    final shadingNos = [for (final sh in _shadings) add(_ascii(sh))];
    final shading = shadingNos.isEmpty
        ? ''
        : ' /Shading << ${[for (var i = 0; i < shadingNos.length; i++) '/Sh${i + 1} ${shadingNos[i]} 0 R'].join(' ')} >>';
    final resources = '<< /Font << /F1 $f1 0 R /F2 $f2 0 R /F3 $f3 0 R >>$shading >>';

    final pageNos = <int>[];
    for (var i = 0; i < total; i++) {
      final footer = StringBuffer(_pages[i].toString());
      final label = '${clean(title)}  -  page ${i + 1} of $total  -  not therapy, not a diagnosis';
      footer.write('BT ${kPdfMuted._fill} rg /F1 8.5 Tf ${margin.toStringAsFixed(2)} 30 Td '
          '(${_escape(label)}) Tj ET\n');
      final contentNo = add(_streamObject('', latin1.encode(footer.toString())));
      pageNos.add(add(_ascii('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pageW $pageH] '
          '/Resources $resources /Contents $contentNo 0 R >>')));
    }
    objects[0] = _ascii('<< /Type /Catalog /Pages 2 0 R >>');
    objects[1] = _ascii('<< /Type /Pages /Kids [${pageNos.map((n) => '$n 0 R').join(' ')}] '
        '/Count $total >>');
    final infoNo = add(_ascii('<< /Title (${_escape(title)}) /Creator (MindPal) /Producer (MindPal) '
        '/CreationDate ($date) >>'));

    final out = BytesBuilder()..add(_ascii('%PDF-1.4\n'))..add([0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out
        ..add(_ascii('${i + 1} 0 obj\n'))
        ..add(objects[i])
        ..add(_ascii('\nendobj\n'));
    }
    final xref = out.length;
    final tail = StringBuffer('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final o in offsets) {
      tail.write('${o.toString().padLeft(10, '0')} 00000 n \n');
    }
    tail.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R /Info $infoNo 0 R >>\n'
        'startxref\n$xref\n%%EOF\n');
    out.add(_ascii(tail.toString()));
    return out.toBytes();
  }
}
