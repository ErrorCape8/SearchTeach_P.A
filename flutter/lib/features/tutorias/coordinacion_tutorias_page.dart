import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/career_catalog.dart';
import '../../core/neu/neu.dart';
import '../../core/widgets/role_toast.dart';
import '../pa/pa_store.dart';
import '../pa/pa_widgets.dart';
import 'informe_general_pages.dart';

const _wine = Color(0xFF800020);

class CoordinacionTutoriasPage extends ConsumerStatefulWidget {
  const CoordinacionTutoriasPage({this.editingId, super.key});
  final String? editingId;

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
    _editingId = widget.editingId;
    _loadTeachers();
    _loadCreatedTutorias();
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
      if (mounted) {
        setState(() => _error =
            _apiError(error, fallback: 'No se pudieron cargar los docentes.'));
      }
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
          'El servidor devolvió una lista de tutorías vacía.',
        );
      }
      final tutorias = data.whereType<Map<String, dynamic>>().toList();
      if (!mounted) return;
      setState(() {
        _createdTutorias = tutorias;
        _loadingTutorias = false;
        _error = null;
      });

      if (widget.editingId != null) {
        final match = tutorias.firstWhere(
          (t) => t['id']?.toString() == widget.editingId,
          orElse: () => const {},
        );
        if (match.isNotEmpty) {
          _editTutoria(match);
        }
      }
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

  String _teacherName(dynamic id) {
    if (id == null) return '—';
    final str = id.toString();
    for (final t in _teachers) {
      if (t['id']?.toString() == str || t['_id']?.toString() == str) {
        final name = t['nombre']?.toString();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return str;
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
            'El docente líder y los cinco docentes de apoyo deben ser distintos.';
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
          'El servidor devolvió una tutoría incompleta.',
        );
      }
      await _loadCreatedTutorias();
      ref.invalidate(paStoreProvider);
      if (!mounted) return;
      setState(() {
        _editingId = null;
        _selectedSection = 1;
      });
      RoleToast.show(
        context,
        message: 'Tutoría colectiva guardada exitosamente.',
        roleColor: _wine,
      );
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
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(dioProvider).delete<void>(
        '/api/coordinacion/tutorias-colectivas/$id',
        queryParameters: const {'confirmacion': 'eliminar'},
      );
      await _loadCreatedTutorias();
      ref.invalidate(paStoreProvider);
      if (mounted) {
        RoleToast.show(
          context,
          message: 'Tutoría colectiva eliminada.',
          roleColor: _wine,
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
          context,
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

  Future<void> _disolverTutoria(Map<String, dynamic> tutoria) async {
    final id = tutoria['id'];
    if (id is! String || id.isEmpty) return;
    final confirmed = await _confirmDisolve();
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(dioProvider).post<void>(
        '/api/coordinacion/tutorias-colectivas/$id/disolver',
        queryParameters: const {'confirmacion': 'disolver'},
      );
      await _loadCreatedTutorias();
      ref.invalidate(paStoreProvider);
      if (mounted) {
        RoleToast.show(
          context,
          message: 'Grupo de proyecto de aula disuelto.',
          roleColor: _wine,
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        RoleToast.showSnackBar(
          context,
          SnackBar(
              content: Text(_apiError(error,
                  fallback: 'No se pudo disolver la tutoría colectiva.'))),
        );
      }
    }
  }

  Future<bool> _confirmDisolve() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Disolver grupo',
              style: neuPoppins(size: 18, weight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Se archivará el grupo y se conservarán sus proyectos, reportes y chats. Escribe DISOLVER para continuar.',
              style: neuBody(color: Neu.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              onChanged: (_) => refresh(() {}),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF1F4F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _wine),
              onPressed: controller.text.trim().toLowerCase() == 'disolver'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Disolver'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return confirmed == true;
  }

  Future<bool> _confirmDelete() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Eliminar tutoría colectiva',
              style: neuPoppins(size: 18, weight: FontWeight.w700)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              'Escribe ELIMINAR para borrar la tutoría y sus proyectos asociados.',
              style: neuBody(color: Neu.muted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              onChanged: (_) => refresh(() {}),
              decoration: InputDecoration(
                labelText: 'Escribe ELIMINAR',
                filled: true,
                fillColor: const Color(0xFFF1F4F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: controller.text.trim().toUpperCase() == 'ELIMINAR'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return confirmed == true;
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neu.bg,
      body: SafeArea(
        child: Column(
          children: [
            NeuHeader(
              title: 'Proyectos de aula',
              subtitle: 'Crea y administra grupos de proyecto de aula',
              leading: NeuCircleButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Volver',
                onTap: () => Navigator.of(context).maybePop(),
              ),
              actions: const [],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Row(
                  children: [
                    Expanded(
                      child: NeuSurface(
                        radius: 16,
                        sunken: _selectedSection == 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onTap: () => setState(() => _selectedSection = 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _editingId != null
                                  ? Icons.edit_rounded
                                  : Icons.add_circle_outline_rounded,
                              size: 18,
                              color: _selectedSection == 0 ? _wine : Neu.muted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _editingId != null
                                  ? 'Editar proyecto de aula'
                                  : 'Nuevo proyecto de aula',
                              style: neuPoppins(
                                size: 13.5,
                                weight: FontWeight.w700,
                                color:
                                    _selectedSection == 0 ? _wine : Neu.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeuSurface(
                        radius: 16,
                        sunken: _selectedSection == 1,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onTap: () => setState(() => _selectedSection = 1),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 18,
                              color: _selectedSection == 1 ? _wine : Neu.muted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Proyectos (${_createdTutorias.length})',
                              style: neuPoppins(
                                size: 13.5,
                                weight: FontWeight.w700,
                                color:
                                    _selectedSection == 1 ? _wine : Neu.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: _selectedSection == 0
                      ? _buildForm()
                      : _createdContent(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          NeuSurface(
            radius: 22,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      _editingId != null
                          ? Icons.edit_note_rounded
                          : Icons.group_add_rounded,
                      color: _wine,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _editingId != null
                            ? 'Editar grupo de proyectos de aula'
                            : 'Crear grupo de proyectos de aula',
                        style: neuPoppins(
                          size: 19,
                          weight: FontWeight.w700,
                          color: Neu.heading,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Define la carrera y el semestre, asigna un docente líder y cinco docentes de apoyo.',
                  style: neuBody(color: Neu.muted, size: 13),
                ),
                const SizedBox(height: 20),
                const PaFieldLabel('Carrera', first: true),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Neu.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _career,
                      items: careerCatalog
                          .map((career) => DropdownMenuItem(
                                value: career,
                                child: Text(career,
                                    style: neuBody(color: Neu.heading)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _career = value;
                            _leaderId = null;
                            _supportIds = List<String?>.filled(5, null);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const PaFieldLabel('Semestre'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Neu.line),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _semester,
                      items: [
                        for (var value = 1; value <= 6; value++)
                          DropdownMenuItem(
                            value: value,
                            child: Text('Semestre $value',
                                style: neuBody(color: Neu.heading)),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _semester = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const PaFieldLabel('Docente líder'),
                _teacherDropdown(
                  label: 'Docente líder',
                  value: _leaderId,
                  excluded: _supportIds.whereType<String>().toSet(),
                  onChanged: (value) => setState(() => _leaderId = value),
                ),
                const SizedBox(height: 18),
                Text(
                  'DOCENTES DE APOYO (5 REQUERIDOS)',
                  style: neuPoppins(
                    size: 11,
                    weight: FontWeight.w700,
                    color: _wine,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < 5; index++) ...[
                  PaFieldLabel('Docente de apoyo ${index + 1}'),
                  _teacherDropdown(
                    label: 'Seleccionar docente',
                    value: _supportIds[index],
                    excluded: {
                      if (_leaderId != null) _leaderId!,
                      ..._supportIds.whereType<String>()
                    }..remove(_supportIds[index]),
                    onChanged: (value) =>
                        setState(() => _supportIds[index] = value),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  PaInfo(_error!, tone: PaTone.error),
                ],
                const SizedBox(height: 22),
                NeuButton(
                  _editingId != null ? 'Guardar cambios' : 'Crear grupo',
                  icon: Icons.check_circle_outline_rounded,
                  loading: _saving,
                  onPressed: _saving ? null : _create,
                ),
                if (_editingId != null) ...[
                  const SizedBox(height: 10),
                  NeuButton(
                    'Cancelar edición',
                    kind: NeuButtonKind.alt,
                    icon: Icons.close_rounded,
                    onPressed: _cancelEdit,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _createdContent() {
    if (_loadingTutorias) {
      return const Center(child: CircularProgressIndicator(color: _wine));
    }
    if (_error != null && _createdTutorias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: neuBody(color: Neu.muted)),
              const SizedBox(height: 14),
              NeuButton('Reintentar',
                  kind: NeuButtonKind.alt,
                  small: true,
                  expand: false,
                  icon: Icons.refresh_rounded,
                  onPressed: _loadCreatedTutorias),
            ],
          ),
        ),
      );
    }
    if (_createdTutorias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Todavía no has creado tutorías colectivas.',
            style: neuBody(color: Neu.muted, size: 14),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
      itemCount: _createdTutorias.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tutoria = _createdTutorias[index];
        final id = '${tutoria['id'] ?? ''}';
        final tech = tutoria['tecnologia'] ?? 'Carrera';
        final sem = tutoria['semestre'] ?? '—';
        final leaderName = _teacherName(tutoria['docenteLiderId']);
        final isDisuelta = tutoria['estado'] == 'DISUELTA';
        final proyectosCount =
            (tutoria['proyectos'] as List?)?.length ?? 0;

        return NeuSurface(
          radius: 20,
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _wine.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.groups_rounded, color: _wine, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => paPush(
                    context,
                    InformeGeneralCoordinacionPage(
                      tutoriaId: id,
                      grupo: tutoria,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$tech · Semestre $sem',
                        style: neuPoppins(
                          size: 15.5,
                          weight: FontWeight.w700,
                          color: Neu.heading,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Docente líder: ',
                              style: neuBody(
                                size: 13,
                                weight: FontWeight.w700,
                                color: Neu.heading,
                              ),
                            ),
                            TextSpan(
                              text: leaderName,
                              style: neuBody(
                                size: 13,
                                color: _wine,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isDisuelta) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Grupo disuelto · historial conservado',
                          style: neuBody(size: 12, color: Colors.blueGrey),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        '$proyectosCount proyectos · ID $id',
                        style: neuBody(size: 12, color: Neu.muted),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isDisuelta) ...[
                NeuCircleButton(
                  icon: Icons.edit_rounded,
                  tooltip: 'Editar',
                  onTap: () => _editTutoria(tutoria),
                ),
                const SizedBox(width: 6),
                NeuCircleButton(
                  icon: Icons.archive_outlined,
                  tooltip: 'Disolver grupo',
                  onTap: () => _disolverTutoria(tutoria),
                ),
                const SizedBox(width: 6),
              ],
              NeuCircleButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Eliminar',
                onTap: () => _deleteTutoria(tutoria),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _teacherDropdown({
    required String label,
    required String? value,
    required Set<String> excluded,
    required ValueChanged<String?> onChanged,
  }) {
    var options = _teachers.where((teacher) {
      final tTec = (teacher['tecnologia'] as String? ?? '').toLowerCase();
      final matchesTec = tTec.isEmpty || tTec == _career.toLowerCase();
      return teacher['id'] is String &&
          matchesTec &&
          (!excluded.contains(teacher['id']) || teacher['id'] == value);
    }).toList();

    if (options.isEmpty) {
      options = _teachers.where((teacher) {
        return teacher['id'] is String &&
            (!excluded.contains(teacher['id']) || teacher['id'] == value);
      }).toList();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Neu.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(
            options.isEmpty
                ? 'No hay docentes disponibles'
                : 'Selecciona un docente',
            style: neuBody(color: Neu.muted),
          ),
          items: options
              .map((teacher) => DropdownMenuItem<String>(
                    value: teacher['id'] as String,
                    child: Text(
                      '${teacher['nombre'] ?? 'Docente'}',
                      style: neuBody(color: Neu.heading),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: _teachers.isEmpty ? null : onChanged,
        ),
      ),
    );
  }
}
