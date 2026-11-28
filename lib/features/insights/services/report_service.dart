import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a finished report to the phone's share sheet. It is an interface so
/// tests can use a fake and never touch the platform.
abstract class ReportSharer {
  /// Saves [bytes] as [fileName] in a temporary folder and opens the share
  /// sheet. The person picks where it goes (Files, e-mail, a messenger, print).
  Future<void> share(Uint8List bytes, String fileName);
}

class PhoneReportSharer implements ReportSharer {
  const PhoneReportSharer();

  @override
  Future<void> share(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'MindPal summary',
        text: 'My MindPal summary (counts only, no journal text).',
      ),
    );
  }
}
