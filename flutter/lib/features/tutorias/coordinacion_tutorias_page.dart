import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';

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
  final _projects = List.generate(5, (_) => _ProjectControllers());
  bool _saving = false;
  String? _error;
  int _selectedSection = 0;
  final List<String> _createdTutorias = [];

  @override
  void dispose() {
    _leader.dispose();
    for (final controller in _supportTeachers) {
      controller.dispose();
    }
    for (final project in _projects) {
      project.dispose();
    }
    super.dispose();
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
          'proyectos': List.generate(
            5,
            (index) => _projects[index].toJson(supportIds[index]),
          ),
        },
      );
      final body = response.data;
      if (body == null || body['id'] is! String || body['proyectos'] is! List) {
        throw const FormatException(
          'El servidor devolvió una tutoría incompleta.',
        );
      }
      final projectIds = (body['proyectos'] as List)
          .map((project) => (project as Map<String, dynamic>)['proyectoId'])
          .whereType<String>()
          .toList();
      if (!mounted) return;
      setState(() {
        _createdTutorias.insert(
          0,
          'Tutoría ${body['id']} creada. '
          'Identificadores de proyectos: ${projectIds.join(', ')}',
        );
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

  String _apiError(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'No se pudo crear la tutoría colectiva. Comprueba tu conexión e inténtalo de nuevo.';
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
                                'Asigna un docente líder, cinco docentes de apoyo y cinco proyectos con cuatro estudiantes cada uno.',
                              ),
                              const SizedBox(height: 20),
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
                                _ProjectFields(
                                  number: index + 1,
                                  controllers: _projects[index],
                                ),
                                const SizedBox(height: 18),
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
              Expanded(child: Text(_createdTutorias[index])),
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

class _ProjectControllers {
  final nombre = TextEditingController();
  final estudiantes = List.generate(4, (_) => TextEditingController());
  final tecnologia = TextEditingController();
  final semestre = TextEditingController(text: '1');

  void dispose() {
    nombre.dispose();
    for (final controller in estudiantes) {
      controller.dispose();
    }
    tecnologia.dispose();
    semestre.dispose();
  }

  Map<String, Object> toJson(String responsableId) => {
        'nombre': nombre.text.trim(),
        'docenteResponsableId': responsableId,
        'estudianteIds':
            estudiantes.map((controller) => controller.text.trim()).toList(),
        'tecnologia': tecnologia.text.trim(),
        'semestre': int.parse(semestre.text.trim()),
      };
}

class _ProjectFields extends StatelessWidget {
  const _ProjectFields({required this.number, required this.controllers});

  final int number;
  final _ProjectControllers controllers;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Proyecto $number',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _requiredField(controllers.nombre, 'Nombre del proyecto'),
              const SizedBox(height: 10),
              for (var index = 0; index < 4; index++) ...[
                _requiredField(
                  controllers.estudiantes[index],
                  'Identificación del estudiante ${index + 1}',
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: _requiredField(controllers.tecnologia, 'Tecnología'),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: controllers.semestre,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Semestre',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final semester = int.tryParse(value ?? '');
                        return semester == null || semester < 1
                            ? 'Inválido'
                            : null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  static Widget _requiredField(
    TextEditingController controller,
    String label,
  ) =>
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
