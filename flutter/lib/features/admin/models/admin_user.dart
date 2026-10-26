class AdminUser {
  const AdminUser({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.rol,
    required this.estado,
    this.carrera = '',
    this.semestre = 0,
    this.titulosAcademicos = const [],
  });

  final String id;
  final String nombre;
  final String correo;
  final String telefono;
  final String rol;
  final String estado;
  final String carrera;
  final int semestre;
  final List<String> titulosAcademicos;

  bool get isActivo => estado.trim().toLowerCase() == 'activo';
  bool get isRevocado => estado.trim().toLowerCase() == 'revocado';

  AdminUser copyWith({
    String? id,
    String? nombre,
    String? correo,
    String? telefono,
    String? rol,
    String? estado,
    String? carrera,
    int? semestre,
    List<String>? titulosAcademicos,
  }) {
    return AdminUser(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      estado: estado ?? this.estado,
      carrera: carrera ?? this.carrera,
      semestre: semestre ?? this.semestre,
      titulosAcademicos: titulosAcademicos ?? this.titulosAcademicos,
    );
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    String readValue(String key) {
      final value = json[key];
      if (value == null) return '';
      if (value is! String) {
        throw FormatException('El dato de usuario "$key" no es válido.');
      }
      return value;
    }

    return AdminUser(
      id: readValue('id'),
      nombre: readValue('nombre'),
      correo: readValue('correo'),
      telefono: readValue('telefono'),
      rol: readValue('rol'),
      estado: readValue('estado'),
      carrera: readValue('carrera'),
      semestre: json['semestre'] is num ? (json['semestre'] as num).toInt() : 0,
      titulosAcademicos: json['titulosAcademicos'] is List
          ? (json['titulosAcademicos'] as List).whereType<String>().toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'correo': correo,
      'telefono': telefono,
      'rol': rol,
      'estado': estado,
      'carrera': carrera,
      'semestre': semestre,
      'titulosAcademicos': titulosAcademicos,
    };
  }
}
