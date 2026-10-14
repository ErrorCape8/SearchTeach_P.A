import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/career_catalog.dart';

class CoordinacionTutoriasPage extends ConsumerStatefulWidget {
  const CoordinacionTutoriasPage({super.key});

  @override
  ConsumerState<CoordinacionTutoriasPage> createState() =>
      _CoordinacionTutoriasPageState();
}

class _CoordinacionTutoriasPageState
    extends ConsumerState<CoordinacionTutoriasPage> {
  final _formKey = GlobalKey<FormState>();
  final _leader = TextEditingController();
  final _supportTeachers = List.generate(5, (_) => TextEditingController());
  String _career = careerCatalog.first;
  int _semester = 1;
  bool _saving = false;
  bool _loadingTutorias = true;
  String? _error;
  int _selectedSection = 0;
  List<Map<String, dynamic>> _createdTutorias = const [];

  @override
  void initState() {
    super.initState();
    _loadCreatedTutorias();
  }

  @override
  void dispose() {
    _leader.dispose();
    for (final controller in _supportTeachers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCreatedTutorias() async {
    setState(() {
      _loadingTutorias = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(dioProvider)
          .get<List<dynamic>>('/api/coordinacion/tutorias-colectivas');
      final data = response.data;
      if (data == null) {
        throw const FormatException(
          'El servidor devolvió una lista de tutorías vacía.',
        );
      }
      final tutorias = data.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
            'El servidor devolvió una tutoría colectiva inválida.',
          );
        }
        return entry;
      }).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _createdTutorias = tutorias;
        _loadingTutorias = false;
        _error = null;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _apiError(
          error,
          fallback: 'No se pudieron cargar las tutorías colectivas.',
        );
        _loadingTutorias = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loadingTutorias = false;
      });
    }
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    final supportIds =
        _supportTeachers.map((controller) => controller.text.trim()).toList();
    if (supportIds.toSet().length != supportIds.length ||
        supportIds.contains(_leader.text.trim())) {
      setState(() {
        _error =
            'El docente líder y los cinco docentes de apoyo deben ser distintos.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await ref.read(dioProvider).post<Map<String, dynamic>>(
        '/api/coordinacion/tutorias-colectivas',
        data: {
          'docenteLiderId': _leader.text.trim(),
          'docentesApoyoIds': supportIds,
          'tecnologia': _career,
          'semestre': _semester,
        },
      );
      final body = response.data;
      if (body == null || body['id'] is! String) {
        throw const FormatException(
          'El servidor devolvió una tutoría incompleta.',
        );
      }
      await _loadCreatedTutorias();
      if (!mounted) return;
      setState(() {
        _selectedSection = 1;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() => _error = _apiError(error));
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteTutoria(Map<String, dynamic> tutoria) async {
    final id = tutoria['id'];
    if (id is! String || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar tutoría colectiva'),
        content: const Text(
          'Se eliminarán también los proyectos, las inscripciones y los informes asociados. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(dioProvider)
          .delete<void>('/api/coordinacion/tutorias-colectivas/$id');
      await _loadCreatedTutorias();
    } on DioException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _apiError(error,
                  fallback: 'No se pudo eliminar la tutoría colectiva.'),
            ),
          ),
        );
      }
    }
  }

  String _apiError(
    DioException error, {
    String fallback = 'No se pudo crear la tutoría colectiva.',
  }) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return '$fallback Comprueba tu conexión e inténtalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Tutorías de proyectos de aula'),
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
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: SegmentedButton<int>(
                    segments: [
                      const ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.add_circle_outline),
                        label: Text('Nueva tutoría'),
                      ),
                      ButtonSegment(
                        value: 1,
                        icon: const Icon(Icons.folder_outlined),
                        label: Text('Creadas (${_createdTutorias.length})'),
                      ),
                    ],
                    selected: {_selectedSection},
                    onSelectionChanged: (selection) {
                      setState(() => _selectedSection = selection.first);
                    },
                  ),
                ),
                Expanded(
                  child: _selectedSection == 0
                      ? Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              const Text(
                                'Crear acompañamiento colectivo',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Define la carrera y el semestre, asigna un docente líder y cinco docentes de apoyo. Los estudiantes registrarán sus proyectos desde su cuenta.',
                              ),
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                initialValue: _career,
                                decoration: const InputDecoration(
                                  labelText: 'Carrera',
                                  border: OutlineInputBorder(),
                                ),
                                items: careerCatalog
                                    .map((career) => DropdownMenuItem(
                                          value: career,
                                          child: Text(career),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _career = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: _semester,
                                decoration: const InputDecoration(
                                  labelText: 'Semestre',
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  for (var value = 1; value <= 6; value++)
                                    DropdownMenuItem(
                                      value: value,
                                      child: Text('$value'),
                                    ),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _semester = value);
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              _textField(
                                _leader,
                                'Identificación del docente líder',
                              ),
                              const SizedBox(height: 12),
                              for (var index = 0; index < 5; index++) ...[
                                _sectionTitle('Docente de apoyo ${index + 1}'),
                                _textField(
                                  _supportTeachers[index],
                                  'Identificación del docente',
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (_error != null)
                                _MessageBox(message: _error!, isError: true),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _saving ? null : _create,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('Crear tutoría colectiva'),
                              ),
                            ],
                          ),
                        )
                      : _createdContent(),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _createdContent() {
    if (_loadingTutorias) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _createdTutorias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadCreatedTutorias,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_createdTutorias.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Todavía no has creado tutorías colectivas.'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _createdTutorias.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.groups_outlined, color: Colors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_createdTutorias[index]['tecnologia'] ?? 'Carrera'} · '
                      'Semestre ${_createdTutorias[index]['semestre'] ?? '—'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Docente líder: ${_createdTutorias[index]['docenteLiderId'] ?? '—'}'),
                    Text(
                      '${(_createdTutorias[index]['proyectos'] as List?)?.length ?? 0} proyectos · '
                      'ID ${_createdTutorias[index]['id'] ?? '—'}',
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Eliminar tutoría colectiva',
                onPressed: () => _deleteTutoria(_createdTutorias[index]),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _textField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Este dato es obligatorio.'
            : null,
      );
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError ? Colors.red.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(message),
      );
}
