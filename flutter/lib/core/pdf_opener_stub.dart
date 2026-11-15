import 'dart:io';
import 'dart:typed_data';

Future<void> openPdfBytes(Uint8List bytes, String name) async {
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
  final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}$safe.pdf');
  await file.writeAsBytes(bytes, flush: true);
  if (Platform.isWindows) {
    await Process.run('cmd', ['/c', 'start', '', file.path]);
  } else if (Platform.isMacOS) {
    await Process.run('open', [file.path]);
  } else if (Platform.isLinux) {
    await Process.run('xdg-open', [file.path]);
  } else {
    throw const FormatException(
      'Abrir PDF no está disponible en esta plataforma. Usa la versión web o de escritorio.',
    );
  }
}
