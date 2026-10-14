import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin_controller.dart';
import '../models/admin_user.dart';

class AdminEditarUsuarioView extends ConsumerStatefulWidget {
  const AdminEditarUsuarioView({
    super.key,
    required this.user,
    required this.onDone,
  });

  final AdminUser user;
  final VoidCallback onDone;

  @override
  ConsumerState<AdminEditarUsuarioView> createState() =>
      _AdminEditarUsuarioViewState();
}

class _AdminEditarUsuarioViewState
    extends ConsumerState<AdminEditarUsuarioView> {
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _correoCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _passCtrl;

  late String _selectedRol;
  late String _selectedEstado;

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.user.nombre);
    _correoCtrl = TextEditingController(text: widget.user.correo);
    _telefonoCtrl = TextEditingController(text: widget.user.telefono);
    _passCtrl = TextEditingController();

    _selectedRol = widget.user.rol;
    _selectedEstado = widget.user.estado;
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _toggleAcceso() {
    setState(() {
      _selectedEstado =
          _selectedEstado.trim().toLowerCase() == 'activo' ? 'Revocado' : 'Activo';
    });
  }

  Future<void> _guardar() async {
    final updated = widget.user.copyWith(
      nombre: _nombreCtrl.text.trim(),
      correo: _correoCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      rol: _selectedRol,
      estado: _selectedEstado,
    );

    final pass = _passCtrl.text.trim();
    if (pass.isNotEmpty && pass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La nueva contraseña debe tener al menos 8 caracteres.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    await ref.read(adminControllerProvider.notifier).updateUser(
          updated,
          nuevaContrasena: pass.isNotEmpty ? pass : null,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario actualizado con éxito.'),
          backgroundColor: Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActivo = _selectedEstado.trim().toLowerCase() == 'activo';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        // NOMBRE
        const _FieldLabel('NOMBRE'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _nombreCtrl,
          hint: 'Nombre completo',
        ),
        const SizedBox(height: 18),

        // CORREO INSTITUCIONAL
        const _FieldLabel('CORREO INSTITUCIONAL'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _correoCtrl,
          hint: 'correo@comfenalco.edu.co',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 18),

        // TELÉFONO
        const _FieldLabel('TELÉFONO'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _telefonoCtrl,
          hint: 'Número de teléfono',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 18),

        // NUEVA CONTRASEÑA
        const _FieldLabel('NUEVA CONTRASEÑA'),
        const SizedBox(height: 6),
        _buildTextField(
          controller: _passCtrl,
          hint: 'Déjala vacía para no cambiarla',
          obscureText: true,
        ),
        const SizedBox(height: 4),
        const Text(
          'Mínimo 8 caracteres.',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF8C95A6),
          ),
        ),
        const SizedBox(height: 18),

        // ROL
        const _FieldLabel('ROL'),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildRoleChip('Estudiante'),
            const SizedBox(width: 10),
            _buildRoleChip('Docente'),
            if (_selectedRol.contains('Coordinador')) ...[
              const SizedBox(width: 10),
              _buildRoleChip('Coordinador'),
            ],
          ],
        ),
        const SizedBox(height: 22),

        // ACCESO
        const _FieldLabel('ACCESO'),
        const SizedBox(height: 8),
        Row(
          children: [
            // Badge estado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActivo
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isActivo ? 'Activo' : 'Revocado',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isActivo
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
            ),
            const Spacer(),
            // Botón de acción: Revocar o Activar
            GestureDetector(
              onTap: _toggleAcceso,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActivo
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActivo ? 'Revocar acceso' : 'Activar acceso',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isActivo
                        ? const Color(0xFF991B1B)
                        : const Color(0xFF166534),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 36),

        // Botones de acción: Cancelar y Guardar cambios
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: widget.onDone,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xFFEA580C),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Guardar cambios',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF8C95A6),
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    final isSelected = _selectedRol == role ||
        (_selectedRol.contains('Docente') &&
            _selectedRol.contains('Estudiante') &&
            (role == 'Docente' || role == 'Estudiante'));

    return GestureDetector(
      onTap: () => setState(() => _selectedRol = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFEA580C)
              : const Color(0xFFF1F4F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          role,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}
