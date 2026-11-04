import 'package:flutter/material.dart';
import '../models/admin_user.dart';

class AdminDetalleUsuarioView extends StatelessWidget {
  const AdminDetalleUsuarioView({
    super.key,
    required this.user,
    required this.onEdit,
  });

  final AdminUser user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final academicDetails = [
      if (user.carrera.isNotEmpty) user.carrera,
      if (user.semestre > 0) 'Semestre ${user.semestre}',
    ].join(' · ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      children: [
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE7EAF0)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                _DetailRow(label: 'DOCUMENTO', value: user.id),
                _DetailRow(label: 'CORREO', value: user.correo),
                _DetailRow(label: 'TELÉFONO', value: user.telefono),
                _DetailRow(
                  label: 'TECNOLOGÍA',
                  value: academicDetails.isEmpty
                      ? 'No registrada'
                      : academicDetails,
                ),
                _DetailRow(label: 'ROL', value: user.rol),
                _DetailRow(label: 'ESTADO', value: user.estado),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onEdit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEA7408),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Editar usuario'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _AdminEditNotice(),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEF0F4))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8A93A2),
                fontSize: 11,
                letterSpacing: .5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(
              value.isEmpty ? 'No registrado' : value,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _AdminEditNotice extends StatelessWidget {
  const _AdminEditNotice();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1DF),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Text(
          'Los cambios de rol, acceso y contraseña se aplican al guardar.',
          style: TextStyle(
            color: Color(0xFFB45309),
            fontSize: 10,
          ),
        ),
      );
}
