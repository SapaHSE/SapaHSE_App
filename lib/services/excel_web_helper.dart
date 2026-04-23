import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class WebDownloadHelper {
  static void download(List<int> bytes, String fileName) {
    final uint8list = Uint8List.fromList(bytes);
    final blob = web.Blob([uint8list.toJS].toJS);
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.click();

    web.URL.revokeObjectURL(url);
  }
}
