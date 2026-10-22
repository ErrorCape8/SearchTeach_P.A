import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'notification_push_service.dart';

class NotificationItem {
  const NotificationItem({required this.id, required this.title,
    required this.message, required this.createdAt, required this.read});
  final String id;
  final String title;
  final String message;
  final DateTime? createdAt;
  final bool read;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? 'Notificación',
    message: json['message'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    read: json['read'] == true,
  );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notificaciones')),
    body: const NotificationsInbox(),
  );
}

class NotificationsInbox extends ConsumerStatefulWidget {
  const NotificationsInbox({super.key});
  @override
  ConsumerState<NotificationsInbox> createState() => _NotificationsInboxState();
}

class _NotificationsInboxState extends ConsumerState<NotificationsInbox> {
  List<NotificationItem> _items = const [];
  bool _loading = true;
  bool _enabling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await ref.read(dioProvider).get<List<dynamic>>('/api/notificaciones');
      if (!mounted) return;
      setState(() {
        _items = (response.data ?? const []).whereType<Map<String, dynamic>>()
            .map(NotificationItem.fromJson).toList(growable: false);
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() { _error = _messageFrom(error); _loading = false; });
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

  Future<void> _markRead(NotificationItem item) async {
    if (item.read) return;
    try {
      await ref.read(dioProvider).patch<void>('/api/notificaciones/${item.id}/leida');
      await _load();
    } on DioException catch (error) {
      if (mounted) _show(_messageFrom(error));
    }
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(dioProvider).patch<void>('/api/notificaciones/leidas');
      await _load();
    } on DioException catch (error) {
      if (mounted) _show(_messageFrom(error));
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _messageFrom(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'No se pudieron cargar las notificaciones. Revisa tu conexión.';
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text('Avisos de tu cuenta', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Wrap(spacing: 8, children: [
              OutlinedButton.icon(
                onPressed: _enabling ? null : _enablePush,
                icon: _enabling ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.notifications_active_outlined),
                label: const Text('Activar en este dispositivo'),
              ),
              if (_items.any((item) => !item.read))
                TextButton(onPressed: _markAllRead, child: const Text('Marcar todo como leído')),
            ]),
          ],
        ),
      ),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Reintentar'))])))
          : _items.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.notifications_none, size: 46), SizedBox(height: 12), Text('Todavía no tienes notificaciones.'), SizedBox(height: 6), Text('Aquí aparecerán avisos de tutorías y actividad académica.', textAlign: TextAlign.center)])))
            : RefreshIndicator(onRefresh: _load, child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Card(child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.read ? Colors.blueGrey.withValues(alpha: .12) : Theme.of(context).colorScheme.primary.withValues(alpha: .12),
                      child: Icon(item.read ? Icons.notifications_none : Icons.notifications_active_outlined,
                        color: item.read ? Colors.blueGrey : Theme.of(context).colorScheme.primary),
                    ),
                    title: Text(item.title, style: TextStyle(fontWeight: item.read ? FontWeight.w500 : FontWeight.w800)),
                    subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text('${item.message}${item.createdAt == null ? '' : '\n${item.createdAt!.toLocal()}'}')),
                    onTap: () => _markRead(item),
                  ));
                },
              )),
      ),
    ],
  );
}
