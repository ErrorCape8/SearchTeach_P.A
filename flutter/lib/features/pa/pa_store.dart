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

  /// Reportes enviados por el docente LÍDER de cada colectiva. Los de los
  /// docentes de apoyo no se listan: la coordinación solo recibe el del líder.
  List<PaReporte> get reportesDeLider => reportes.where((r) {
        final i = colectivas.indexWhere((c) => c.id == r.colId);
        return i >= 0 && paMismoNombre(r.por, colectivas[i].lider);
      }).toList();

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
                por: 'Sofía Rojas',
                estudiante: 'Camilo Andres',
                puntajes: [4, 4, 5, 4],
                obs: 'Falta documentar el modelo.'),
            PaRubrica(
                colId: 2,
                por: 'Sofía Rojas',
                estudiante: 'Daniela Castro',
                puntajes: [4, 4, 4, 4],
                obs: ''),
          ],
          visto: true,
        ),
      ],
    );

/// Estado de las vistas de proyecto de aula (tutorías colectivas). Vive en memoria con los datos del prototipo HTML.
/// Para conectarlo al backend basta con reemplazar los métodos de [PaStore]
/// por llamadas a la API y mantener la misma forma de [PaState].
class PaStore extends StateNotifier<PaState> {
  PaStore([this._dio]) : super(_seed()) {
    cargarDeApi();
  }

  final Dio? _dio;

  Future<void> cargarDeApi() async {
    final dio = _dio;
    if (dio == null) return;
    try {
      final res = await dio.get<List<dynamic>>('/api/coordinacion/tutorias-colectivas');
      final list = (res.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (list.isNotEmpty) {
        final loaded = <PaColectiva>[];
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          final rawId = item['id']?.toString() ?? '$i';
          final intId = int.tryParse(rawId.replaceAll(RegExp(r'\D'), '')) ?? i;
          final sem = item['semestre'] is int ? item['semestre'] as int : 1;
          final sec = item['seccion'] is int ? item['seccion'] as int : 1;
          final tech = (item['tecnologia'] ?? item['carrera'] ?? 'Ing. de Sistemas').toString();
          final leader = (item['docenteLiderId'] ?? item['lider'] ?? '').toString();
          final rawApoyos = item['docentesApoyoIds'] ?? item['apoyo'];
          final apoyos = (rawApoyos is List)
              ? rawApoyos.map((e) => e.toString()).toList()
              : <String>[];
          final aula = (item['aula'] ?? 'Sala virtual').toString();
          final cuando = (item['cuando'] ?? item['horario'] ?? 'Por programar').toString();
          final materia = (item['materia'] ?? 'Proyecto de Aula $sem').toString();

          loaded.add(PaColectiva(
            id: intId,
            materia: materia,
            carrera: tech,
            semestre: sem,
            seccion: sec,
            lider: leader,
            apoyo: apoyos,
            cuando: cuando,
            aula: aula,
          ));
        }

        if (loaded.isNotEmpty) {
          state = state.copyWith(colectivas: loaded);
        }
      }
    } catch (_) {
      // Fallback seguro a los datos de _seed()
    }

    try {
      final repRes = await dio.get<List<dynamic>>('/api/coordinacion/informes-generales');
      final repList = (repRes.data ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList();
      if (repList.isNotEmpty) {
        final loadedRep = <PaReporte>[];
        for (final r in repList) {
          final colId = int.tryParse((r['tutoriaId'] ?? '0').toString().replaceAll(RegExp(r'\D'), '')) ?? 0;
          final por = (r['docenteId'] ?? r['por'] ?? 'Docente').toString();
          final fecha = (r['creadoEn'] ?? r['fecha'] ?? 'Reciente').toString();
          loadedRep.add(PaReporte(
            colId: colId,
            por: por,
            fecha: fecha,
            asistencia: const {},
            rubricas: const [],
            visto: r['visto'] == true,
          ));
        }
        if (loadedRep.isNotEmpty) {
          state = state.copyWith(reportes: [...loadedRep, ...state.reportes]);
        }
      }
    } catch (_) {
      // Fallback a los reportes de seed
    }
  }

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
    StateNotifierProvider<PaStore, PaState>((ref) => PaStore(ref.watch(dioProvider)));

final paAulasProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final r = await dio.get<List<dynamic>>('/api/coordinacion/horarios');
    final aulas = (r.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((h) => (h['aula'] ?? '').toString())
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList();
    return aulas.isEmpty ? paAulas : aulas;
  } catch (_) {
    return paAulas;
  }
});

final paAlumnosProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final r = await dio.get<List<dynamic>>('/api/coordinacion/sesiones-grupales');
    final alumnos = <String>{};
    for (final s in (r.data ?? const []).whereType<Map<String, dynamic>>()) {
      final list = s['estudiantes'] ?? s['estudianteNombres'];
      if (list is List) {
        for (final e in list) {
          final n = e.toString().trim();
          if (n.isNotEmpty) alumnos.add(n);
        }
      }
    }
    return alumnos.isEmpty ? paAlumnos : alumnos.toList();
  } catch (_) {
    return paAlumnos;
  }
});

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
