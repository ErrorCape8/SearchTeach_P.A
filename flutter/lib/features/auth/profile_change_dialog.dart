import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

Future<void> showProfileChangeDialog(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onUpdated,
}) async {
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();
  final code = TextEditingController();
  var codeSent = false;
  var busy = false;
  String? errorMessage;

  final updated = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(codeSent ? 'Verificar identidad' : 'Cambiar datos de cuenta'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!codeSent) ...[
              const Text('Deja en blanco los datos que no quieras cambiar. Enviaremos un código al correo actual de tu cuenta.'),
              const SizedBox(height: 14),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Nuevo correo electrónico')),
              const SizedBox(height: 10),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nuevo número de teléfono')),
              const SizedBox(height: 10),
              TextField(controller: password, obscureText: true, maxLength: 72, decoration: const InputDecoration(labelText: 'Nueva contraseña', helperText: 'Mínimo 8 caracteres')),
            ] else ...[
              const Text('Escribe el código de seis dígitos enviado a tu correo registrado. Vence en 10 minutos.'),
              const SizedBox(height: 14),
              TextField(
                controller: code,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Código de seguridad', counterText: ''),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ]),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setDialogState(() {
                      busy = true;
                      errorMessage = null;
                    });
                    try {
                      if (!codeSent) {
                        final payload = <String, String>{
                          if (email.text.trim().isNotEmpty) 'correo': email.text.trim(),
                          if (phone.text.trim().isNotEmpty) 'telefono': phone.text.trim(),
                          if (password.text.isNotEmpty) 'nuevaContrasena': password.text,
                        };
                        if (payload.isEmpty) {
                          setDialogState(() => errorMessage = 'Completa al menos un dato para cambiar.');
                          return;
                        }
                        await ref.read(dioProvider).post('/api/usuarios/perfil/cambios/solicitar', data: payload);
                        setDialogState(() => codeSent = true);
                      } else {
                        if (!RegExp(r'^[0-9]{6}$').hasMatch(code.text)) {
                          setDialogState(() => errorMessage = 'El código debe tener seis dígitos.');
                          return;
                        }
                        await ref.read(dioProvider).post('/api/usuarios/perfil/cambios/verificar', data: {'codigo': code.text});
                        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                      }
                    } on DioException catch (error) {
                      final data = error.response?.data;
                      setDialogState(() => errorMessage = data is Map && data['message'] is String
                          ? data['message'] as String
                          : 'No se pudo completar la solicitud.');
                    } finally {
                      if (dialogContext.mounted) setDialogState(() => busy = false);
                    }
                  },
            child: busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(codeSent ? 'Verificar y guardar' : 'Enviar código'),
          ),
        ],
      ),
    ),
  );

  email.dispose();
  phone.dispose();
  password.dispose();
  code.dispose();
  if (updated == true) {
    onUpdated?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cambios verificados y guardados.')),
      );
    }
  }
}
