import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

const paCriterios = [
  'Avance del proyecto',
  'Calidad técnica',
  'Documentación',
  'Sustentación',
];
const paAulas = [
  'D501',
  'C303',
  'F405',
  'F603',
  'D303',
  'C101',
  'Sala virtual',
];
const paAlumnos = [
  'Camilo Andres',
  'Valentina Ruiz',
  'Juan Pablo Mora',
  'Daniela Castro',
];
const paRomanos = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

String paNorm(String s) {
  const from = 'áéíóúüñ';
  const to = 'aeiouun';
  var r = s.trim().toLowerCase();
  for (var i = 0; i < from.length; i++) {
    r = r.replaceAll(from[i], to[i]);
  }
  return r;
}

bool paMismoNombre(String a, String b) {
  final na = paNorm(a);
  final nb = paNorm(b);
  if (na.isEmpty || nb.isEmpty) return false;
  return na == nb || na.startsWith('$nb ') || nb.startsWith('$na ');
}

double paPromedio(Iterable<num> values) {
  final list = values.toList();
  if (list.isEmpty) return 0;
  return list.fold<double>(0, (a, b) => a + b) / list.length;
}

class PaUsuario {
  const PaUsuario({
    required this.nombre,
    required this.programa,
    required this.semestre,
  });
  final String nombre;
  final String programa;
  final int? semestre;
}

class PaColectiva {
  const PaColectiva({
    required this.id,
    required this.materia,
    required this.carrera,
    required this.semestre,
    required this.seccion,
    required this.lider,
    required this.apoyo,
    required this.cuando,
    required this.aula,
  });

  final int id;
  final String materia;
  final String carrera;
  final int semestre;
  final int seccion;
  final String lider;
  final List<String> apoyo;
  final String cuando;
  final String aula;

  bool get virtual => aula == 'Sala virtual';
  String get modalidad => virtual ? 'Virtual' : 'Física';
  String get aulaLabel => virtual ? 'Sala virtual' : 'Aula $aula';
  String get semestreRomano => paRomanos[semestre.clamp(0, 10)];
  String get fecha => cuando.split(' · ').first;
  String get hora => cuando.contains(' · ') ? cuando.split(' · ').last : '';

  PaColectiva copyWith({String? lider, List<String>? apoyo, String? aula}) =>
      PaColectiva(
        id: id,
        materia: materia,
        carrera: carrera,
        semestre: semestre,
        seccion: seccion,
        lider: lider ?? this.lider,
        apoyo: apoyo ?? this.apoyo,
        cuando: cuando,
        aula: aula ?? this.aula,
      );
}

class PaRubrica {
  const PaRubrica({
    required this.colId,
    required this.por,
    required this.estudiante,
    required this.puntajes,
    required this.obs,
  });
  final int colId;
  final String por;
  final String estudiante;
  final List<int> puntajes;
  final String obs;
  double get promedio => paPromedio(puntajes);
}

class PaReporte {
  const PaReporte({
    required this.colId,
    required this.por,
    required this.fecha,
    required this.asistencia,
    required this.rubricas,
    required this.visto,
  });
  final int colId;
  final String por;
  final String fecha;
  final Map<String, bool> asistencia;
  final List<PaRubrica> rubricas;
  final bool visto;

  PaReporte conVisto() => PaReporte(
        colId: colId,
        por: por,
        fecha: fecha,
        asistencia: asistencia,
        rubricas: rubricas,
        visto: true,
      );
}

class PaState {
  const PaState({
    required this.colectivas,
    required this.rubricas,
    required this.asistencia,
    required this.reportes,
  });

  final List<PaColectiva> colectivas;
  final List<PaRubrica> rubricas;
  final Map<int, Map<String, bool>> asistencia;
  final List<PaReporte> reportes;

  PaColectiva colectiva(int id) => colectivas.firstWhere((c) => c.id == id);

  List<String> get nombresDocentes {
    final set = <String>{};
    for (final c in colectivas) {
      if (c.lider.isNotEmpty) set.add(c.lider);
      set.addAll(c.apoyo);
    }
    return set.toList()..sort();
  }

  PaState copyWith({
    List<PaColectiva>? colectivas,
    List<PaRubrica>? rubricas,
    Map<int, Map<String, bool>>? asistencia,
    List<PaReporte>? reportes,
  }) =>
      PaState(
        colectivas: colectivas ?? this.colectivas,
        rubricas: rubricas ?? this.rubricas,
        asistencia: asistencia ?? this.asistencia,
        reportes: reportes ?? this.reportes,
      );
}

PaState _seed() => PaState(
      colectivas: const [
        PaColectiva(
            id: 0,
            materia: 'ING. Desarrollo',
            carrera: 'Ing. de Sistemas',
            semestre: 6,
            seccion: 1,
            lider: 'Laura Martínez',
            apoyo: ['Carlos Chavarriaga', 'Andrea Quintero', 'Mauricio Pardo'],
            cuando: 'Vie 4 sep 2026 · 6:45 – 8:15 PM',
            aula: 'D501'),
        PaColectiva(
            id: 1,
            materia: 'Bases de Datos II',
            carrera: 'Ing. de Sistemas',
            semestre: 6,
            seccion: 1,
            lider: '',
            apoyo: [],
            cuando: 'Mié 2 sep 2026 · 2:00 – 4:15 PM',
            aula: 'Sala virtual'),
        PaColectiva(
            id: 2,
            materia: 'Proyecto Integrador',
            carrera: 'Ing. de Sistemas',
            semestre: 8,
            seccion: 1,
            lider: 'Sofía Rojas',
            apoyo: ['Laura Martínez', 'Natalia Herrera'],
            cuando: 'Lun 31 ago 2026 · 6:45 – 9:00 PM',
            aula: 'F603'),
        PaColectiva(
            id: 3,
            materia: 'Programación II',
            carrera: 'Ing. de Sistemas',
            semestre: 4,
            seccion: 1,
            lider: 'Carlos Chavarriaga',
            apoyo: ['Julián Barrios', 'Andrea Quintero', 'Mauricio Pardo'],
            cuando: 'Jue 3 sep 2026 · 7:00 – 8:30 AM',
            aula: 'C303'),
        PaColectiva(
            id: 4,
            materia: 'Programación II',
            carrera: 'Ing. de Sistemas',
            semestre: 4,
            seccion: 2,
            lider: 'Julián Barrios',
            apoyo: ['Carlos Chavarriaga', 'Natalia Herrera'],
            cuando: 'Jue 3 sep 2026 · 6:45 – 9:45 PM',
            aula: 'D303'),
        PaColectiva(
            id: 5,
            materia: 'Introducción a la Ingeniería',
            carrera: 'Ing. Industrial',
            semestre: 2,
            seccion: 1,
            lider: 'Andrea Quintero',
            apoyo: ['Sofía Rojas', 'Natalia Herrera'],
            cuando: 'Mar 1 sep 2026 · 6:45 – 9:45 PM',
            aula: 'C101'),
        PaColectiva(
            id: 6,
            materia: 'Diseño de Procesos',
            carrera: 'Ing. Industrial',
            semestre: 4,
            seccion: 1,
            lider: '',
            apoyo: [],
            cuando: 'Jue 3 sep 2026 · 9:00 – 10:30 AM',
            aula: 'Sala virtual'),
      ],
      rubricas: const [
        PaRubrica(
            colId: 0,
            por: 'Carlos Chavarriaga',
            estudiante: 'Valentina Ruiz',
            puntajes: [4, 5, 4, 4],
            obs: 'Buen avance en el diseño.'),
      ],
      asistencia: const {},
      reportes: const [
        PaReporte(
          colId: 2,
          por: 'Sofía Rojas',
          fecha: '30 sep',
          asistencia: {
            'Camilo Andres': true,
            'Valentina Ruiz': true,
            'Juan Pablo Mora': false,
            'Daniela Castro': true,
          },
          rubricas: [
            PaRubrica(
                colId: 2,
                por: 'Laura Martínez',
                estudiante: 'Camilo Andres',
                puntajes: [4, 4, 5, 4],
                obs: 'Falta documentar el modelo.'),
            PaRubrica(
                colId: 2,
                por: 'Laura Martínez',
                estudiante: 'Daniela Castro',
                puntajes: [4, 4, 4, 4],
                obs: ''),
          ],
          visto: false,
        ),
      ],
    );

/// Estado de las vistas de proyecto de aula (tutorías colectivas). Vive en memoria con los datos del prototipo HTML.
/// Para conectarlo al backend basta con reemplazar los métodos de [PaStore]
/// por llamadas a la API y mantener la misma forma de [PaState].
class PaStore extends StateNotifier<PaState> {
  PaStore() : super(_seed());

  Map<String, bool> asistenciaDe(int colId) => state.asistencia[colId] ?? {};

  void toggleAsistencia(int colId, String alumno) {
    final actual = Map<String, bool>.from(asistenciaDe(colId));
    actual[alumno] = !(actual[alumno] ?? false);
    state = state.copyWith(asistencia: {...state.asistencia, colId: actual});
  }

  void guardarRubrica(PaRubrica r) {
    final lista = state.rubricas
        .where((x) => !(x.colId == r.colId &&
            x.por == r.por &&
            x.estudiante == r.estudiante))
        .toList()
      ..add(r);
    state = state.copyWith(rubricas: lista);
  }

  bool reporteEnviado(int colId, String por) => state.reportes
      .any((r) => r.colId == colId && r.por == por && r.fecha == 'hoy');

  void enviarReporte(int colId, String por) {
    final at = asistenciaDe(colId);
    final reporte = PaReporte(
      colId: colId,
      por: por,
      fecha: 'hoy',
      asistencia: {for (final a in paAlumnos) a: at[a] ?? false},
      rubricas: state.rubricas.where((x) => x.colId == colId).toList(),
      visto: false,
    );
    state = state.copyWith(reportes: [reporte, ...state.reportes]);
  }

  void marcarVisto(PaReporte r) {
    state = state.copyWith(
      reportes: [
        for (final x in state.reportes) identical(x, r) ? x.conVisto() : x,
      ],
    );
  }

  void asignar(int colId, String lider, List<String> apoyo, String aula) {
    state = state.copyWith(colectivas: [
      for (final c in state.colectivas)
        c.id == colId ? c.copyWith(lider: lider, apoyo: apoyo, aula: aula) : c,
    ]);
  }

}

final paStoreProvider =
    StateNotifierProvider<PaStore, PaState>((ref) => PaStore());

final paUsuarioProvider = FutureProvider.autoDispose<PaUsuario>((ref) async {
  try {
    final r = await ref
        .read(dioProvider)
        .get<Map<String, dynamic>>('/api/usuarios/perfil');
    final d = r.data ?? const <String, dynamic>{};
    final sem = int.tryParse(
        (d['semestre'] ?? '').toString().replaceAll(RegExp(r'\D'), ''));
    return PaUsuario(
      nombre: (d['nombre'] ?? '').toString(),
      programa: (d['programa'] ?? d['carrera'] ?? '').toString(),
      semestre: sem,
    );
  } on DioException {
    return const PaUsuario(nombre: '', programa: '', semestre: null);
  }
});

final paDocentesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final seed = ref.read(paStoreProvider).nombresDocentes;
  try {
    final r =
        await ref.read(dioProvider).get<List<dynamic>>('/api/coordinacion/docentes');
    final names = (r.data ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map((e) => (e['nombre'] ?? '').toString())
        .where((n) => n.isNotEmpty)
        .toList();
    return names.isEmpty ? seed : names;
  } on DioException {
    return seed;
  }
});
