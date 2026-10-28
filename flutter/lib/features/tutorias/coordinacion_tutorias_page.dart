import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../auth/auth_repository.dart';
import '../notifications/notifications_page.dart';
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
  String _career = careerCatalog.first;
  String? _leaderId;
  List<String?> _supportIds = List<String?>.filled(5, null);
  List<Map<String, dynamic>> _teachers = const [];
  int _semester = 1;
  bool _saving = false;
  bool _loadingTutorias = true;
  String? _error;
  String? _editingId;
  int _selectedSection = 0;
  List<Map<String, dynamic>> _createdTutorias = const [];

  @override
  void initState() {
    super.initState();
    _loadCreatedTutorias();
    _loadTeachers();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadTeachers() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get<List<dynamic>>('/api/coordinacion/docentes');
      if (!mounted) return;
      setState(() => _teachers = (response.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList());
    } on DioException catch (error) {
      if (mounted)
        setState(() => _error =
            _apiError(error, fallback: 'No se pudieron cargar los docentes.'));
    }
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
          'El servidor devolviÃ³ una lista de tutorÃ­as vacÃ­a.',
        );
      }
      final tutorias = data.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException(
            'El servidor devolviÃ³ una tutorÃ­a colectiva invÃ¡lida.',
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
          fallback: 'No se pudieron cargar las tutorÃ­as colectivas.',
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
    final supportIds = _supportIds.whereType<String>().toList();
    if (_leaderId == null ||
        supportIds.length != 5 ||
        supportIds.toSet().length != 5 ||
        supportIds.contains(_leaderId)) {
      setState(() {
        _error =
            'El docente lÃ­der y los cinco docentes de apoyo deben ser distintos.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'docenteLiderId': _leaderId,
        'docentesApoyoIds': supportIds,
        'tecnologia': _career,
        'semestre': _semester,
      };
      final response = _editingId == null
          ? await dio.post<Map<String, dynamic>>(
              '/api/coordinacion/tutorias-colectivas',
              data: payload)
          : await dio.put<Map<String, dynamic>>(
              '/api/coordinacion/tutorias-colectivas/$_editingId',
              data: payload);
      final body = response.data;
      if (body == null || body['id'] is! String) {
        throw const FormatException(
          'El servidor devolviÃ³ una tutorÃ­a incompleta.',
        );
      }
      await _loadCreatedTutorias();
      if (!mounted) return;
      setState(() {
        _editingId = null;
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

  void _editTutoria(Map<String, dynamic> tutoria) {
    final id = tutoria['id'];
    final supports = (tutoria['docentesApoyoIds'] as List? ?? const [])
        .whereType<String>()
        .toList();
    if (id is! String || id.isEmpty || supports.length != 5) {
      setState(() => _error = 'No se pudo cargar la asignación de docentes.');
      return;
    }
    final career = tutoria['tecnologia'] is String
        ? tutoria['tecnologia'] as String
        : careerCatalog.first;
    setState(() {
      _editingId = id;
      _career = careerCatalog.contains(career) ? career : careerCatalog.first;
      _semester =
          tutoria['semestre'] is num ? (tutoria['semestre'] as num).toInt() : 1;
      _leaderId = tutoria['docenteLiderId'] as String?;
      _supportIds = supports.cast<String?>();
      _selectedSection = 0;
      _error = null;
    });
  }

  // ignore: unused_element
  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _leaderId = null;
      _supportIds = List<String?>.filled(5, null);
      _error = null;
    });
  }

  Future<void> _deleteTutoria(Map<String, dynamic> tutoria) async {
    final id = tutoria['id'];
    if (id is! String || id.isEmpty) return;
    final confirmed = await _confirmDelete();
    /*final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar tutorÃ­a colectiva'),
        content: const Text(
          'Se eliminarÃ¡n tambiÃ©n los proyectos, las inscripciones y los informes asociados. '
          'Esta acciÃ³n no se puede deshacer.',
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
    );*/
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
                  fallback: 'No se pudo eliminar la tutorÃ­a colectiva.'),
            ),
          ),
        );
      }
    }
  }

  Future<bool> _confirmDelete() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Eliminar tutoría colectiva'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
                'Escribe ELIMINAR para borrar la tutoría y sus proyectos asociados.'),
            TextField(
                controller: controller,
                onChanged: (_) => refresh(() {}),
                decoration:
                    const InputDecoration(labelText: 'Escribe ELIMINAR')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: controller.text.trim().toUpperCase() == 'ELIMINAR'
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Eliminar')),
          ],
        ),
      ),
    );
    controller.dispose();
    return confirmed == true;
  }

  String _apiError(
    DioException error, {
    String fallback = 'No se pudo crear la tutorÃ­a colectiva.',
  }) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return '$fallback Comprueba tu conexiÃ³n e intÃ©ntalo de nuevo.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('TutorÃ­as de proyectos de aula'),
          actions: [
            const NotificationBellButton(),
            IconButton(
              tooltip: 'Cerrar sesiÃ³n',
              onPressed: () async {
                await ref.read(authRepositoryProvider).logout();
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
                        label: Text('Nueva tutorÃ­a'),
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
                                'Crear acompaÃ±amiento colectivo',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Define la carrera y el semestre, asigna un docente lÃ­der y cinco docentes de apoyo. Los estudiantes registrarÃ¡n sus proyectos desde su cuenta.',
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
                                    setState(() {
                                      _career = value;
                                      _leaderId = null;
                                      _supportIds =
                                          List<String?>.filled(5, null);
                                    });
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
                              _teacherDropdown(
                                  label: 'Docente líder',
                                  value: _leaderId,
                                  excluded:
                                      _supportIds.whereType<String>().toSet(),
                                  onChanged: (value) =>
                                      setState(() => _leaderId = value)),
                              const SizedBox(height: 12),
                              for (var index = 0; index < 5; index++) ...[
                                _sectionTitle('Docente de apoyo ${index + 1}'),
                                _teacherDropdown(
                                    label: 'Seleccionar docente',
                                    value: _supportIds[index],
                                    excluded: {
                                      if (_leaderId != null) _leaderId!,
                                      ..._supportIds.whereType<String>()
                                    }..remove(_supportIds[index]),
                                    onChanged: (value) => setState(
                                        () => _supportIds[index] = value)),
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
                                label: const Text('Crear tutorÃ­a colectiva'),
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
          child: Text('TodavÃ­a no has creado tutorÃ­as colectivas.'),
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
                      '${_createdTutorias[index]['tecnologia'] ?? 'Carrera'} Â· '
                      'Semestre ${_createdTutorias[index]['semestre'] ?? 'â€”'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        'Docente lÃ­der: ${_createdTutorias[index]['docenteLiderId'] ?? 'â€”'}'),
                    Text(
                      '${(_createdTutorias[index]['proyectos'] as List?)?.length ?? 0} proyectos Â· '
                      'ID ${_createdTutorias[index]['id'] ?? 'â€”'}',
                    ),
                  ],
                ),
              ),
              IconButton(
                  tooltip: 'Editar',
                  onPressed: () => _editTutoria(_createdTutorias[index]),
                  icon: const Icon(Icons.edit_outlined)),
              IconButton(
                tooltip: 'Eliminar tutorÃ­a colectiva',
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

  Widget _teacherDropdown(
      {required String label,
      required String? value,
      required Set<String> excluded,
      required ValueChanged<String?> onChanged}) {
    final options = _teachers
        .where((teacher) =>
            (teacher['tecnologia'] as String? ?? '').toLowerCase() ==
                _career.toLowerCase() &&
            teacher['id'] is String &&
            (!excluded.contains(teacher['id']) || teacher['id'] == value))
        .toList();
    return DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
            labelText: label, border: const OutlineInputBorder()),
        items: options
            .map((teacher) => DropdownMenuItem<String>(
                value: teacher['id'] as String,
                child: Text(teacher['nombre'] as String? ?? 'Docente')))
            .toList(),
        onChanged: _teachers.isEmpty ? null : onChanged,
        validator: (selected) =>
            selected == null ? 'Selecciona un docente.' : null,
        hint: Text(options.isEmpty
            ? 'No hay docentes para esta tecnología'
            : 'Selecciona'));
  }
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
