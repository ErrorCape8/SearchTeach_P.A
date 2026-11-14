import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/neu/neu.dart';
import '../../pa/pa_widgets.dart';
import '../admin_controller.dart';

/// Texto de la última sincronización semestral. Reemplázalo por el dato real
/// cuando el backend lo exponga.
const _ultimaSync =
    'Última sincronización: 02 feb 2026 (+34 cuentas nuevas, 12 accesos revocados).';

String _miles(int n) {
  final s = n.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write('.');
    out.write(s[i]);
  }
  return out.toString();
}

class AdminInicioView extends ConsumerWidget {
  const AdminInicioView({super.key, this.onOpenCertifications});

  final VoidCallback? onOpenCertifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminControllerProvider);
    final stats = state.stats;
    final pendingCertifications = ref.watch(adminPendingCertificationsProvider);
    final sinActivar = state.users.where((user) => !user.hasPassword).length;

    Widget certRow() => pendingCertifications.when(
          data: (count) => PaRow(
            icon: Icons.description_outlined,
            title: 'Certificados pendientes: $count',
            subtitle: count == 0
                ? 'No hay solicitudes por revisar.'
                : 'Solicitudes de docentes por revisar.',
            onTap: onOpenCertifications,
          ),
          error: (error, _) => PaRow(
            icon: Icons.error_outline,
            title: 'No se pudieron cargar los certificados',
            subtitle: 'Toca para reintentar.',
            onTap: () => ref.invalidate(adminPendingCertificationsProvider),
          ),
          loading: () => const PaRow(
            icon: Icons.description_outlined,
            title: 'Cargando certificados pendientes…',
            subtitle: 'Consultando solicitudes de docentes.',
          ),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(
          18, 4, 18, 32 + MediaQuery.paddingOf(context).bottom),
      children: [
        if (state.statsError != null) ...[
          PaInfo(state.statsError!, tone: PaTone.error),
          NeuButton('Reintentar',
              kind: NeuButtonKind.alt,
              icon: Icons.refresh_rounded,
              onPressed: () =>
                  ref.read(adminControllerProvider.notifier).loadStats()),
        ] else if (state.isLoadingStats || stats == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(color: Color(0xFFEA580C)),
            ),
          )
        else ...[
          PaKpiRow([
            (_miles(stats.cuentasActivas), 'Cuentas activas'),
            (_miles(stats.docentes), 'Docentes'),
            (_miles(stats.suspendidos), 'Suspendidos'),
          ]),
          PaRowList([certRow()]),
          if (!state.isLoadingUsers && state.usersError == null && sinActivar > 0)
            PaRowList([
              PaRow(
                icon: Icons.person_add_alt_1_outlined,
                title: 'Cuentas sin activar: $sinActivar',
                subtitle: 'Usuarios que todavía no han creado su contraseña.',
                onTap: () => ref.read(adminControllerProvider.notifier).setTab(1),
              ),
            ]),
          const PaSection('Sincronización semestral'),
          PaCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'Matrícula y vinculación con Registro y Control y Talento Humano. Se ejecuta automáticamente cada semestre.',
                style: neuBody(size: 14, color: Neu.muted, height: 1.4),
              ),
              const PaInfo(_ultimaSync),
            ]),
          ),
        ],
      ],
    );
  }
}

String _dateLabel(DateTime value) {
  const weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${weekdays[value.weekday - 1]} ${value.day} de '
      '${months[value.month - 1]} de ${value.year}';
}

