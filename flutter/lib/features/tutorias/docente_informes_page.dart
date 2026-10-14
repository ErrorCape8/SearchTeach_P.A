import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

final _proyectosAsignadosProvider =
    FutureProvider.autoDispose<List<_ProyectoAsignado>>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/docente/tutorias-colectivas');
  final data = response.data;
  if (data == null) {
    throw const FormatException('El servidor devolvió una lista vacía inválida.');
  }
  return data.map((entry) {
    if (entry is! Map<String, dynamic> ||
        entry['tutoriaColectivaId'] is! String ||
        entry['proyecto'] is! Map<String, dynamic>) {
      throw const FormatException('Un proyecto asignado tiene datos inválidos.');
    }
    final project = entry['proyecto'] as Map<String, dynamic>;
    if (project['proyectoId'] is! String ||
        project['nombre'] is! String ||
        project['tecnologia'] is! String ||
        project['semestre'] is! num) {
      throw const FormatException('Los datos de un proyecto asignado están incompletos.');
    }
    return _ProyectoAsignado(
      tutoriaColectivaId: entry['tutoriaColectivaId'] as String,
      proyectoId: project['proyectoId'] as String,
      nombre: project['nombre'] as String,
      tecnologia: project['tecnologia'] as String,
      semestre: (project['semestre'] as num).toInt(),
    );
  }).toList(growable: false);
});

class DocenteInformesPage extends ConsumerStatefulWidget {
  const DocenteInformesPage({super.key});

  @override
  ConsumerState<DocenteInformesPage> createState() => _DocenteInformesPageState();
}

class _DocenteInformesPageState extends ConsumerState<DocenteInformesPage> {
  final _formKey = GlobalKey<FormState>();
  final _score = TextEditingController();
  final _observations = TextEditingController();
  String? _selectedProjectId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _score.dispose();
    _observations.dispose();
    super.dispose();
  }

  Future<void> _submit(_ProyectoAsignado project) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(dioProvider).post(
        '/api/docente/tutorias-colectivas/'
        '${Uri.encodeComponent(project.tutoriaColectivaId)}/proyectos/'
        '${Uri.encodeComponent(project.proyectoId)}/informes',
        data: {
          'puntajeAvance': int.parse(_score.text.trim()),
          'observaciones': _observations.text.trim(),
        },
      );
      if (!mounted) return;
      _score.clear();
      _observations.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe de avance enviado al líder del programa.')),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      final data = error.response?.data;
      setState(() {
        _error = data is Map && data['message'] is String
            ? data['message'] as String
            : 'No se pudo enviar el informe. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Informe de tutoría'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              onPressed: () async {
                await ref.read(secureStorageProvider).delete(key: 'token');
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: ref.watch(_proyectosAsignadosProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorContent(
                message: 'No se pudieron cargar tus proyectos asignados: $error',
                onRetry: () => ref.invalidate(_proyectosAsignadosProvider),
              ),
              data: (projects) => _buildProjects(context, projects),
            ),
      );

  Widget _buildProjects(
    BuildContext context,
    List<_ProyectoAsignado> projects,
  ) {
    if (projects.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tienes proyectos asignados como docente de apoyo.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final selected = projects.any((project) => project.proyectoId == _selectedProjectId)
        ? _selectedProjectId!
        : projects.first.proyectoId;
    final selectedProject =
        projects.firstWhere((project) => project.proyectoId == selected);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Reportar avance del proyecto',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Usa el mismo criterio de puntuación de 0 a 100 en cada informe para que el seguimiento sea comparable.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: const InputDecoration(
            labelText: 'Proyecto asignado',
            border: OutlineInputBorder(),
          ),
          items: projects
              .map((project) => DropdownMenuItem(
                    value: project.proyectoId,
                    child: Text(
                      '${project.nombre} · ${project.tecnologia} · semestre ${project.semestre}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(growable: false),
          onChanged: (value) => setState(() => _selectedProjectId = value),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _score,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Puntaje de avance (0–100)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final score = int.tryParse(value ?? '');
                  return score == null || score < 0 || score > 100
                      ? 'Ingresa un número entre 0 y 100.'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _observations,
                minLines: 4,
                maxLines: 7,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Observaciones del avance',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Describe brevemente el avance.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : () => _submit(selectedProject),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Enviar informe'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProyectoAsignado {
  const _ProyectoAsignado({
    required this.tutoriaColectivaId,
    required this.proyectoId,
    required this.nombre,
    required this.tecnologia,
    required this.semestre,
  });

  final String tutoriaColectivaId;
  final String proyectoId;
  final String nombre;
  final String tecnologia;
  final int semestre;
}

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.message, required this.onRetry});

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
