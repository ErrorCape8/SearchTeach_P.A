import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/role_toast.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import 'notification_push_service.dart';

final notificationUnreadCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<Map<String, dynamic>>('/api/notificaciones/no-leidas/count');
  final count = response.data?['count'];
  if (count is! num || count < 0) {
    throw const FormatException(
      'El servidor devolvió un contador de notificaciones inválido.',
    );
  }
  return count.toInt();
});

class NotificationUnreadIcon extends ConsumerWidget {
  const NotificationUnreadIcon({super.key, required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(notificationUnreadCountProvider);
    final count = unreadCount.asData?.value ?? 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            top: -7,
            right: -9,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class NotificationBellButton extends ConsumerWidget {
  const NotificationBellButton({super.key, this.accentColor});

  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
        tooltip: 'Notificaciones',
        onPressed: () {
          ref.invalidate(notificationUnreadCountProvider);
          context.push('/notificaciones', extra: accentColor);
        },
        icon: const NotificationUnreadIcon(
          icon: Icons.notifications_outlined,
        ),
      );
}

class NotificationItem {
  const NotificationItem(
      {required this.id,
      required this.title,
      required this.message,
      required this.route,
      required this.createdAt,
      required this.read});
  final String id;
  final String title;
  final String message;
  final String? route;
  final DateTime? createdAt;
  final bool read;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Notificación',
        message: json['message'] as String? ?? '',
        route: json['route'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        read: json['read'] == true,
      );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, this.accentColor});

  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleTheme = accentColor == null
        ? theme
        : theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(primary: accentColor),
          );
    return Theme(
      data: roleTheme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: accentColor,
          foregroundColor: accentColor == null ? null : Colors.white,
          title: const Text('Avisos'),
        ),
        body: NotificationsInbox(accentColor: accentColor),
      ),
    );
  }
}

class NotificationsInbox extends ConsumerStatefulWidget {
  const NotificationsInbox({
    super.key,
    this.accentColor,
    this.htmlStyle = false,
  });

  final Color? accentColor;
  final bool htmlStyle;
  @override
  ConsumerState<NotificationsInbox> createState() => _NotificationsInboxState();
}

class _NotificationsInboxState extends ConsumerState<NotificationsInbox> {
  List<NotificationItem> _items = const [];
  bool _loading = true;
  bool _enabling = false;
  bool _pushEnabled = false;
  bool _pushStatusLoading = true;
  String? _error;
  final Set<String> _expandedNotifications = {};

  @override
  void initState() {
    super.initState();
    _loadPushStatus();
    _load();
  }

  Future<void> _loadPushStatus() async {
    final enabled = await isDeviceNotificationsEnabled();
    if (mounted) {
      setState(() {
        _pushEnabled = enabled;
        _pushStatusLoading = false;
      });
    }
  }

  Future<void> _load() async {
    ref.invalidate(notificationUnreadCountProvider);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await ref.read(dioProvider).get<List<dynamic>>('/api/notificaciones');
      if (!mounted) return;
      setState(() {
        _items = (response.data ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(NotificationItem.fromJson)
            .toList(growable: false);
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFrom(error);
        _loading = false;
      });
    }
  }

  Future<void> _enablePush() async {
    setState(() => _enabling = true);
    try {
      final token = await enableDeviceNotifications(ref.read(dioProvider));
      if (!mounted) return;
      if (token == null) {
        _show('Firebase aún no está configurado para esta aplicación.');
      } else if (token.isEmpty) {
        _show('No se concedió permiso para mostrar notificaciones.');
      } else {
        setState(() => _pushEnabled = true);
        _show('Este dispositivo ya puede recibir notificaciones.');
      }
    } on DioException catch (error) {
      if (mounted) _show(_messageFrom(error));
    } catch (error) {
      if (mounted) _show('No se pudieron activar las notificaciones: $error');
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  Future<void> _disablePush() async {
    setState(() => _enabling = true);
    try {
      await disableDeviceNotifications(ref.read(dioProvider));
      if (!mounted) return;
      setState(() => _pushEnabled = false);
      _show('Se desactivaron las notificaciones en este dispositivo.');
    } on DioException catch (error) {
      if (mounted) _show(_messageFrom(error));
    } catch (error) {
      if (mounted) {
        _show('No se pudieron desactivar las notificaciones: $error');
      }
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  Future<void> _markRead(NotificationItem item) async {
    try {
      if (!item.read) {
        await ref.read(dioProvider).patch<void>(
            '/api/notificaciones/${Uri.encodeComponent(item.id)}/leida');
        ref.invalidate(notificationUnreadCountProvider);
        await _load();
      }
    } on DioException catch (error) {
      if (mounted) _show(_messageFrom(error));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(dioProvider).patch<void>('/api/notificaciones/leidas');
      ref.invalidate(notificationUnreadCountProvider);
      await _load();
    } on DioException catch (error) {
      if (mounted) _show(_messageFrom(error));
    }
  }

  void _show(String message) {
    RoleToast.showSnackBar(context, SnackBar(content: Text(message)));
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'No se pudieron cargar las notificaciones. Revisa tu conexión.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleTheme = widget.accentColor == null
        ? theme
        : theme.copyWith(
            colorScheme:
                theme.colorScheme.copyWith(primary: widget.accentColor),
          );
    return Theme(
      data: roleTheme,
      child: Builder(builder: _buildInbox),
    );
  }

  Widget _buildInbox(BuildContext context) {
    final unreadCount = ref.watch(notificationUnreadCountProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            widget.htmlStyle ? 22 : 24,
            18,
            widget.htmlStyle ? 22 : 24,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                margin: EdgeInsets.zero,
                elevation: 2,
                shadowColor: const Color(0x12141E3C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                child: SwitchListTile(
                  secondary: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.notifications_active_outlined,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  title: const Text('Notificaciones en este dispositivo',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  subtitle: const Text(
                      'Recibe avisos de tutorías y actividad académica.',
                      style: TextStyle(fontSize: 11)),
                  value: _pushEnabled,
                  onChanged: _enabling || _pushStatusLoading
                      ? null
                      : (enabled) => enabled ? _enablePush() : _disablePush(),
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Recientes',
                        style: TextStyle(
                            fontSize: widget.htmlStyle ? 15 : 16,
                            fontWeight: FontWeight.w800)),
                  ),
                  unreadCount.when(
                    data: (count) => Text(
                      count == 1 ? '1 sin leer' : '$count sin leer',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12),
                    ),
                    loading: () => const Text('Actualizando…'),
                    error: (_, __) => const Text(''),
                  ),
                  if (_items.any((item) => !item.read)) ...[
                    const SizedBox(width: 8),
                    TextButton(
                        onPressed: _markAllRead,
                        child: const Text('Marcar todo leído')),
                  ],
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: _load,
                                child: const Text('Reintentar'))
                          ])))
                  : _items.isEmpty
                      ? const Center(
                          child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.notifications_none, size: 46),
                                    SizedBox(height: 12),
                                    Text('Todavía no tienes notificaciones.'),
                                    SizedBox(height: 6),
                                    Text(
                                        'Aquí aparecerán avisos de tutorías y actividad académica.',
                                        textAlign: TextAlign.center)
                                  ])))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: widget.htmlStyle
                              ? ListView(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                  children: [
                                    Card(
                                      margin: EdgeInsets.zero,
                                      elevation: 2,
                                      shadowColor: const Color(0x12141E3C),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Column(
                                        children: [
                                          for (var index = 0;
                                              index < _items.length;
                                              index++) ...[
                                            if (index > 0)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 14),
                                                child: Divider(
                                                    height: 1,
                                                    color: Color(0xFFE8EBF1)),
                                              ),
                                            _notificationTile(
                                                context, _items[index]),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) =>
                                      _notificationTile(context, _items[index]),
                                )),
        ),
      ],
    );
  }

  Widget _notificationTile(BuildContext context, NotificationItem item) {
    final accent = Theme.of(context).colorScheme.primary;
    return ExpansionTile(
      tilePadding: EdgeInsets.symmetric(
        horizontal: widget.htmlStyle ? 14 : 16,
        vertical: widget.htmlStyle ? 1 : 0,
      ),
      leading: Container(
        width: widget.htmlStyle ? 40 : 42,
        height: widget.htmlStyle ? 40 : 42,
        decoration: BoxDecoration(
          color: item.read
              ? Colors.blueGrey.withValues(alpha: .12)
              : accent.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          item.read
              ? Icons.notifications_none
              : Icons.notifications_active_outlined,
          color: item.read ? Colors.blueGrey : accent,
        ),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontSize: widget.htmlStyle ? 13 : null,
          fontWeight: item.read ? FontWeight.w500 : FontWeight.w800,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          _notificationPreview(item.message),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: widget.htmlStyle ? 11 : null),
        ),
      ),
      initiallyExpanded: _expandedNotifications.contains(item.id),
      onExpansionChanged: (expanded) {
        setState(() {
          if (expanded) {
            _expandedNotifications.add(item.id);
          } else {
            _expandedNotifications.remove(item.id);
          }
        });
        if (expanded) _markRead(item);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.message),
              if (item.createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  _dateLabel(item.createdAt!),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
              if (item.route != null && item.route != '/notificaciones')
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _markReadAndNavigate(item),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ver detalle'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  String _notificationPreview(String message) {
    const maxLength = 72;
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength).trimRight()}…';
  }

  Future<void> _markReadAndNavigate(NotificationItem item) async {
    await _markRead(item);
    const destinations = {
      '/home',
      '/coordinacion',
      '/coordinacion/tutorias-colectivas',
      '/coordinacion/programar-tutorias',
      '/docente',
      '/estudiante',
      '/admin',
    };
    if (!mounted || item.route == null || !destinations.contains(item.route)) {
      return;
    }
    context.go(item.route!);
  }
}
