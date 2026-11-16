import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Abre un archivo PDF a partir de sus bytes.
/// - En Android e iOS: utiliza el FileProvider seguro para delegar la apertura
///   a la aplicación de visualización de PDFs instalada en el dispositivo móvil (Google Drive PDF, Adobe, etc.).
/// - En Windows/macOS/Linux: abre el archivo guardado temporalmente con el programa predeterminado del sistema operativo.
Future<void> openPdfBytes(Uint8List bytes, String name) async {
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');

  final Directory dir;
  if (Platform.isAndroid || Platform.isIOS) {
    dir = await getTemporaryDirectory();
  } else {
    dir = Directory.systemTemp;
  }

  final file = File('${dir.path}${Platform.pathSeparator}$safe.pdf');
  await file.writeAsBytes(bytes, flush: true);

  final result = await OpenFilex.open(file.path, type: 'application/pdf');
  if (result.type != ResultType.done) {
    if (result.type == ResultType.noAppToOpen) {
      throw const FormatException(
        'No se encontró una aplicación para abrir PDFs. Por favor instala un lector de PDF en tu dispositivo.',
      );
    }
    // Fallback para entornos de escritorio si el handler de open_filex no completó
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', file.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [file.path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [file.path]);
    } else {
      throw FormatException(
        result.message.isNotEmpty
            ? result.message
            : 'No se pudo abrir el documento PDF en el dispositivo.',
      );
    }
  }
}

