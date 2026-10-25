import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

enum ProfileChangeField { email, phone, password }

extension on ProfileChangeField {
  String get apiName => switch (this) {
        ProfileChangeField.email => 'correo',
        ProfileChangeField.phone => 'telefono',
        ProfileChangeField.password => 'contrasena',
      };

  String get label => switch (this) {
        ProfileChangeField.email => 'correo electrónico',
        ProfileChangeField.phone => 'número de teléfono',
        ProfileChangeField.password => 'contraseña',
      };

  String get inputLabel => switch (this) {
        ProfileChangeField.email => 'Nuevo correo electrónico',
        ProfileChangeField.phone => 'Nuevo número de teléfono',
        ProfileChangeField.password => 'Nueva contraseña',
      };
}

Future<void> showProfileChangeDialog(
  BuildContext context,
  WidgetRef ref, {
  required ProfileChangeField field,
  VoidCallback? onUpdated,
}) async {
  final value = TextEditingController();
  final code = TextEditingController();
  var stage = 0;
  var busy = false;
  String? errorMessage;

  final updated = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        final title = switch (stage) {
          0 => 'Verificar identidad',
          1 => 'Ingresar código',
          _ => 'Cambiar ${field.label}',
        };
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (stage == 0) ...[
                Text('Enviaremos un código al correo actual de tu cuenta antes de cambiar ${field.label}.'),
              ] else if (stage == 1) ...[
                const Text('Escribe el código de seis dígitos enviado a tu correo. Vence en 10 minutos.'),
                const SizedBox(height: 14),
                TextField(
                  controller: code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Código de verificación', counterText: ''),
                ),
              ] else ...[
                TextField(
                  controller: value,
                  autofocus: true,
                  obscureText: field == ProfileChangeField.password,
                  keyboardType: switch (field) {
                    ProfileChangeField.email => TextInputType.emailAddress,
                    ProfileChangeField.phone => TextInputType.phone,
                    ProfileChangeField.password => TextInputType.visiblePassword,
                  },
                  maxLength: field == ProfileChangeField.password ? 72 : 256,
                  decoration: InputDecoration(
                    labelText: field.inputLabel,
                    helperText: field == ProfileChangeField.password ? 'Mínimo 8 caracteres.' : null,
                  ),
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
                        if (stage == 0) {
                          await ref.read(dioProvider).post(
                            '/api/usuarios/perfil/cambios/solicitar',
                            data: {'campo': field.apiName},
                          );
                          setDialogState(() => stage = 1);
                        } else if (stage == 1) {
                          if (!RegExp(r'^[0-9]{6}$').hasMatch(code.text)) {
                            setDialogState(() => errorMessage = 'El código debe tener seis dígitos.');
                            return;
                          }
                          await ref.read(dioProvider).post(
                            '/api/usuarios/perfil/cambios/verificar',
                            data: {'codigo': code.text},
                          );
                          setDialogState(() => stage = 2);
                        } else {
                          if (value.text.trim().isEmpty) {
                            setDialogState(() => errorMessage = 'Escribe el nuevo dato.');
                            return;
                          }
                          await ref.read(dioProvider).post(
                            '/api/usuarios/perfil/cambios/aplicar',
                            data: {
                              'nuevoValor': field == ProfileChangeField.password
                                  ? value.text
                                  : value.text.trim(),
                            },
                          );
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
                  : Text(switch (stage) {
                      0 => 'Enviar código',
                      1 => 'Verificar código',
                      _ => 'Guardar cambio',
                    }),
            ),
          ],
        );
      },
    ),
  );

  value.dispose();
  code.dispose();
  if (updated == true) {
    onUpdated?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El cambio se guardó correctamente.')),
      );
    }
  }
}
