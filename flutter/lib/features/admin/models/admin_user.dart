class AdminUser {
  const AdminUser({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.telefono,
    required this.rol,
    required this.estado,
  });

  final String id;
  final String nombre;
  final String correo;
  final String telefono;
  final String rol;
  final String estado;

  bool get isActivo => estado.trim().toLowerCase() == 'activo';
  bool get isRevocado => !isActivo;

  AdminUser copyWith({
    String? id,
    String? nombre,
    String? correo,
    String? telefono,
    String? rol,
    String? estado,
  }) {
    return AdminUser(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      estado: estado ?? this.estado,
    );
  }

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      correo: json['correo'] as String? ?? '',
      telefono: json['telefono'] as String? ?? '',
      rol: json['rol'] as String? ?? 'Estudiante',
      estado: json['estado'] as String? ?? 'Activo',
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
    };
  }
}
