import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_client.dart';
import '../neu/neu.dart';
import 'role_toast.dart';

Future<bool> showChangePasswordDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ChangePasswordFlow(ref: ref),
      ) ??
      false;
}

Future<bool> showChangePhoneDialog(
  BuildContext context,
  WidgetRef ref, {
  String? currentPhone,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ChangePhoneFlow(
          ref: ref,
          initialPhone: currentPhone ?? '',
        ),
      ) ??
      false;
}

class _ChangePasswordFlow extends StatefulWidget {
  const _ChangePasswordFlow({required this.ref});
  final WidgetRef ref;

  @override
  State<_ChangePasswordFlow> createState() => _ChangePasswordFlowState();
}

class _ChangePasswordFlowState extends State<_ChangePasswordFlow> {
  int _step = 0;
  bool _sendingCode = true;
  bool _verifyingCode = false;
  bool _savingPassword = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String _maskedEmail = '';
  String? _codeError;
  String? _generalError;

  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _passFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _requestInitialCode();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestInitialCode() async {
    setState(() {
      _sendingCode = true;
      _generalError = null;
    });
    try {
      final res = await widget.ref.read(dioProvider).post<Map<String, dynamic>>(
            '/api/usuarios/perfil/contrasena/codigo',
          );
      final email = res.data?['email']?.toString() ?? 'tu correo institucional';
      if (!mounted) return;
      setState(() {
        _maskedEmail = email;
        _sendingCode = false;
        _step = 1;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _generalError = _extractMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _generalError = 'No se pudo enviar el código. Revisa tu conexión.';
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() {
        _codeError = 'Escribe bien el código de 6 dígitos numéricos.';
      });
      return;
    }
    setState(() {
      _verifyingCode = true;
      _codeError = null;
    });
    try {
      await widget.ref.read(dioProvider).post<void>(
        '/api/usuarios/perfil/contrasena/verificar',
        data: {'code': code},
      );
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _step = 2;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final serverMsg = _extractMessage(e);
      setState(() {
        _verifyingCode = false;
        _codeError = serverMsg.contains('incorrecto') ||
                serverMsg.contains('expirado') ||
                serverMsg.contains('válido')
            ? serverMsg
            : 'Ese no es el código o no coincide. Escríbelo bien o solicita uno nuevo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _codeError = 'Ese no es el código o no coincide. Intenta de nuevo.';
      });
    }
  }

  Future<void> _submitNewPassword() async {
    if (!(_passFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _savingPassword = true;
      _generalError = null;
    });
    try {
      await widget.ref.read(dioProvider).patch<void>(
        '/api/usuarios/perfil/contrasena',
        data: {
          'nuevaContrasena': _newPassCtrl.text,
          'confirmarContrasena': _confirmPassCtrl.text,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      RoleToast.showSnackBar(
        context,
        const SnackBar(content: Text('Contraseña actualizada exitosamente.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingPassword = false;
        _generalError = _extractMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingPassword = false;
        _generalError = 'No se pudo guardar la contraseña. Intenta de nuevo.';
      });
    }
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? 'Ocurrió un error inesperado.';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_reset_rounded, color: primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Cambiar contraseña',
              style: neuPoppins(
                size: 17,
                weight: FontWeight.w700,
                color: Neu.heading,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: _step == 0
            ? _buildInitialLoading(primary)
            : _step == 1
                ? _buildCodeStep(primary)
                : _buildPasswordStep(primary),
      ),
      actions: _step == 0
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ]
          : _step == 1
              ? [
                  TextButton(
                    onPressed: _verifyingCode
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: _verifyingCode ? null : _verifyCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _verifyingCode
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirmar código'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: _savingPassword
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: _savingPassword ? null : _submitNewPassword,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _savingPassword
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ],
    );
  }

  Widget _buildInitialLoading(Color primary) {
    if (_generalError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            _generalError!,
            style: neuBody(size: 13, color: Neu.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _requestInitialCode,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        CircularProgressIndicator(color: primary),
        const SizedBox(height: 16),
        Text(
          'Enviando código a tu correo…',
          style: neuBody(size: 13.5, color: Neu.muted),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCodeStep(Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mark_email_read_outlined, color: primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu código se envió a tu correo ($_maskedEmail).',
                  style: neuBody(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: Neu.heading,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ingresa el código de 6 dígitos:',
          style: neuBody(
            size: 13,
            weight: FontWeight.w600,
            color: Neu.heading,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: neuPoppins(
            size: 20,
            weight: FontWeight.w700,
            letterSpacing: 6,
            color: Neu.heading,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              letterSpacing: 6,
              color: Colors.grey.shade400,
            ),
            filled: true,
            fillColor: const Color(0xFFF1F3F7),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        if (_codeError != null) ...[
          const SizedBox(height: 8),
          Text(
            _codeError!,
            style: neuBody(size: 12, color: Neu.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: _sendingCode ? null : _requestInitialCode,
            child: Text(
              _sendingCode ? 'Enviando…' : '¿No llegó? Enviar otro código',
              style: neuBody(size: 12, color: primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep(Color primary) {
    return Form(
      key: _passFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Código confirmado. Ahora crea tu nueva contraseña:',
            style: neuBody(size: 13, color: Neu.muted),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _newPassCtrl,
            obscureText: _obscureNew,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              filled: true,
              fillColor: const Color(0xFFF1F3F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNew
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
            ),
            validator: (value) => (value == null || value.length < 8)
                ? 'Debe tener al menos 8 caracteres'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPassCtrl,
            obscureText: _obscureConfirm,
            decoration: InputDecoration(
              labelText: 'Confirmar nueva contraseña',
              filled: true,
              fillColor: const Color(0xFFF1F3F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (value) => value != _newPassCtrl.text
                ? 'Las contraseñas no coinciden'
                : null,
            onFieldSubmitted: (_) => _submitNewPassword(),
          ),
          if (_generalError != null) ...[
            const SizedBox(height: 10),
            Text(
              _generalError!,
              style: neuBody(size: 12, color: Neu.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangePhoneFlow extends StatefulWidget {
  const _ChangePhoneFlow({required this.ref, required this.initialPhone});
  final WidgetRef ref;
  final String initialPhone;

  @override
  State<_ChangePhoneFlow> createState() => _ChangePhoneFlowState();
}

class _ChangePhoneFlowState extends State<_ChangePhoneFlow> {
  int _step = 0;
  bool _sendingCode = true;
  bool _verifyingCode = false;
  bool _savingPhone = false;
  String _maskedEmail = '';
  String? _codeError;
  String? _generalError;

  final _codeCtrl = TextEditingController();
  late final TextEditingController _phoneCtrl;
  final _phoneFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone);
    _requestInitialCode();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestInitialCode() async {
    setState(() {
      _sendingCode = true;
      _generalError = null;
    });
    try {
      final res = await widget.ref.read(dioProvider).post<Map<String, dynamic>>(
            '/api/usuarios/perfil/telefono/codigo',
          );
      final email = res.data?['email']?.toString() ?? 'tu correo institucional';
      if (!mounted) return;
      setState(() {
        _maskedEmail = email;
        _sendingCode = false;
        _step = 1;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _generalError = _extractMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _generalError = 'No se pudo enviar el código. Revisa tu conexión.';
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6 || !RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      setState(() {
        _codeError = 'Escribe bien el código de 6 dígitos numéricos.';
      });
      return;
    }
    setState(() {
      _verifyingCode = true;
      _codeError = null;
    });
    try {
      await widget.ref.read(dioProvider).post<void>(
        '/api/usuarios/perfil/telefono/verificar',
        data: {'code': code},
      );
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _step = 2;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final serverMsg = _extractMessage(e);
      setState(() {
        _verifyingCode = false;
        _codeError = serverMsg.contains('incorrecto') ||
                serverMsg.contains('expirado') ||
                serverMsg.contains('válido')
            ? serverMsg
            : 'Ese no es el código o no coincide. Escríbelo bien o solicita uno nuevo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _codeError = 'Ese no es el código o no coincide. Intenta de nuevo.';
      });
    }
  }

  Future<void> _submitPhone() async {
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    final phone = _phoneCtrl.text.trim();
    setState(() {
      _savingPhone = true;
      _generalError = null;
    });
    try {
      await widget.ref.read(dioProvider).patch<void>(
        '/api/usuarios/perfil/telefono',
        data: {'telefono': phone},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      RoleToast.showSnackBar(
        context,
        const SnackBar(content: Text('Teléfono actualizado exitosamente.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _savingPhone = false;
        _generalError = _extractMessage(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savingPhone = false;
        _generalError = 'No se pudo guardar el teléfono. Intenta de nuevo.';
      });
    }
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return e.message ?? 'Ocurrió un error inesperado.';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.phone_iphone_rounded, color: primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Actualizar teléfono',
              style: neuPoppins(
                size: 17,
                weight: FontWeight.w700,
                color: Neu.heading,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: _step == 0
            ? _buildInitialLoading(primary)
            : _step == 1
                ? _buildCodeStep(primary)
                : _buildPhoneStep(primary),
      ),
      actions: _step == 0
          ? [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ]
          : _step == 1
              ? [
                  TextButton(
                    onPressed: _verifyingCode
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: _verifyingCode ? null : _verifyCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _verifyingCode
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Confirmar código'),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: _savingPhone
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: _savingPhone ? null : _submitPhone,
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _savingPhone
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ],
    );
  }

  Widget _buildInitialLoading(Color primary) {
    if (_generalError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            _generalError!,
            style: neuBody(size: 13, color: Neu.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _requestInitialCode,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        CircularProgressIndicator(color: primary),
        const SizedBox(height: 16),
        Text(
          'Enviando código a tu correo…',
          style: neuBody(size: 13.5, color: Neu.muted),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCodeStep(Color primary) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: primary.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.mark_email_read_outlined, color: primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tu código se envió a tu correo ($_maskedEmail).',
                  style: neuBody(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: Neu.heading,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Ingresa el código de 6 dígitos:',
          style: neuBody(
            size: 13,
            weight: FontWeight.w600,
            color: Neu.heading,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: neuPoppins(
            size: 20,
            weight: FontWeight.w700,
            letterSpacing: 6,
            color: Neu.heading,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: TextStyle(
              letterSpacing: 6,
              color: Colors.grey.shade400,
            ),
            filled: true,
            fillColor: const Color(0xFFF1F3F7),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        if (_codeError != null) ...[
          const SizedBox(height: 8),
          Text(
            _codeError!,
            style: neuBody(size: 12, color: Neu.error),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: _sendingCode ? null : _requestInitialCode,
            child: Text(
              _sendingCode ? 'Enviando…' : '¿No llegó? Enviar otro código',
              style: neuBody(size: 12, color: primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneStep(Color primary) {
    return Form(
      key: _phoneFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text(
            'Código confirmado. Escribe tu nuevo número de teléfono:',
            style: neuBody(size: 13, color: Neu.muted),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Número de teléfono',
              hintText: '3001234567',
              filled: true,
              fillColor: const Color(0xFFF1F3F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            ),
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) return 'El teléfono es obligatorio';
              if (text.length < 7 || text.length > 15) {
                return 'Ingresa un número válido (7-15 dígitos)';
              }
              return null;
            },
            onFieldSubmitted: (_) => _submitPhone(),
          ),
          if (_generalError != null) ...[
            const SizedBox(height: 10),
            Text(
              _generalError!,
              style: neuBody(size: 12, color: Neu.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
