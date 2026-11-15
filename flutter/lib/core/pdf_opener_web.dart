import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> openPdfBytes(Uint8List bytes, String name) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final blobUrl = web.URL.createObjectURL(blob);
  web.window.open(blobUrl, '_blank');
  Future.delayed(const Duration(seconds: 60), () {
    web.URL.revokeObjectURL(blobUrl);
  });
}
