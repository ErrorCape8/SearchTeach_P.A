import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../admin_controller.dart';

class AdminInicioView extends ConsumerWidget {
  const AdminInicioView({super.key, this.onOpenCertifications});

  final VoidCallback? onOpenCertifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminControllerProvider);
    final stats = state.stats;
    final pendingCertifications = ref.watch(adminPendingCertificationsProvider);
    final accountsWithoutPassword =
        state.users.where((user) => !user.hasPassword).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        if (state.statsError != null)
          _LoadError(
            message: state.statsError!,
            onRetry: () =>
                ref.read(adminControllerProvider.notifier).loadStats(),
          )
        else if (state.isLoadingStats || stats == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(36),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          _SummaryBanner(
            total: stats.cuentasTotal,
            active: stats.cuentasActivas,
            accountsWithoutPassword: accountsWithoutPassword,
            isLoadingUsers: state.isLoadingUsers,
            hasUsersError: state.usersError != null,
            pendingCertifications: pendingCertifications,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final cards = [
                _MetricCard(
                  value: '${stats.cuentasTotal}',
                  label: 'Cuentas totales',
                ),
                _MetricCard(
                  value: '${stats.cuentasActivas}',
                  label: 'Cuentas activas',
                ),
                _MetricCard(value: '${stats.docentes}', label: 'Docentes'),
                _MetricCard(
                  value: '${stats.suspendidos}',
                  label: 'Suspendidos',
                ),
              ];
              if (!compact) {
                return Row(
                  children: [
                    for (var index = 0; index < cards.length; index++) ...[
                      if (index > 0) const SizedBox(width: 12),
                      Expanded(child: cards[index]),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: cards
                    .map(
                      (card) => SizedBox(
                        width: (constraints.maxWidth - 10) / 2,
                        child: card,
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          if (onOpenCertifications != null) ...[
            pendingCertifications.when(
              data: (count) => _ActionSummaryCard(
                icon: Icons.description_outlined,
                title: 'Certificados pendientes: $count',
                subtitle: count == 0
                    ? 'No hay solicitudes por revisar.'
                    : 'Solicitudes de docentes por revisar.',
                trailing: Icons.chevron_right,
                onTap: onOpenCertifications,
              ),
              error: (error, _) => _ActionSummaryCard(
                icon: Icons.error_outline,
                title: 'No se pudieron cargar los certificados',
                subtitle: '$error',
                trailing: Icons.refresh,
                onTap: () => ref.invalidate(adminPendingCertificationsProvider),
              ),
              loading: () => const _ActionSummaryCard(
                icon: Icons.description_outlined,
                title: 'Cargando certificados pendientes…',
                subtitle: 'Consultando solicitudes de docentes.',
                trailing: Icons.more_horiz,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (!state.isLoadingUsers &&
              state.usersError == null &&
              accountsWithoutPassword > 0)
            _ActionSummaryCard(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Cuentas sin activar: $accountsWithoutPassword',
              subtitle: 'Usuarios que todavía no han creado su contraseña.',
              trailing: Icons.chevron_right,
              onTap: () => ref
                  .read(adminControllerProvider.notifier)
                  .setTab(1),
            ),
          const SizedBox(height: 10),
          _ActionSummaryCard(
            icon: Icons.notifications_active_outlined,
            title: 'Notificaciones push y recordatorios',
            subtitle: 'Avisos en el dispositivo y por correo antes de cada tutoría.',
            trailing: Icons.notifications_none_outlined,
            onTap: () => context.push('/notificaciones'),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1DF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Dato: Los cambios de rol, acceso y contraseña se aplican al guardar.',
              style: TextStyle(
                color: Color(0xFFB45309),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({
    required this.total,
    required this.active,
    required this.accountsWithoutPassword,
    required this.isLoadingUsers,
    required this.hasUsersError,
    required this.pendingCertifications,
  });

  final int total;
  final int active;
  final int accountsWithoutPassword;
  final bool isLoadingUsers;
  final bool hasUsersError;
  final AsyncValue<int> pendingCertifications;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFFFF1E2)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dateLabel(DateTime.now()),
                    style: const TextStyle(
                      color: Color(0xFF8A93A2),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Resumen del sistema',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$total cuentas en total, $active activas y '
                    '${pendingCertifications.valueOrNull ?? '…'} '
                    'solicitud(es) de certificado por revisar.'
                    '${isLoadingUsers ? ' Cargando cuentas sin contraseña…' : hasUsersError ? ' No se pudo consultar la activación de cuentas.' : accountsWithoutPassword > 0 ? ' $accountsWithoutPassword cuentas aún no han creado su contraseña.' : ''}',
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isLoadingUsers ? '…' : hasUsersError ? '!' : '$accountsWithoutPassword',
              style: const TextStyle(
                color: Color(0xFFFFD8B8),
                fontSize: 40,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
}

class _ActionSummaryCard extends StatelessWidget {
  const _ActionSummaryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE7EAF0)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFFEA7408), size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF8A93A2),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(trailing, color: const Color(0xFF94A3B8), size: 18),
              ],
            ),
          ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFFEA580C),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
