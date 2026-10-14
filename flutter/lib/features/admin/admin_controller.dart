import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import 'models/admin_user.dart';

class AdminState {
  const AdminState({
    required this.users,
    this.selectedUser,
    this.activeTab = 0,
    this.searchQuery = '',
    this.filter = 'Todos',
    this.adminPhone = '605 600 0000',
    this.isLoading = false,
    this.errorMessage,
  });

  final List<AdminUser> users;
  final AdminUser? selectedUser;
  final int activeTab;
  final String searchQuery;
  final String filter;
  final String adminPhone;
  final bool isLoading;
  final String? errorMessage;

  List<AdminUser> get filteredUsers {
    return users.where((u) {
      final matchesQuery = searchQuery.isEmpty ||
          u.nombre.toLowerCase().contains(searchQuery.toLowerCase()) ||
          u.correo.toLowerCase().contains(searchQuery.toLowerCase()) ||
          u.rol.toLowerCase().contains(searchQuery.toLowerCase());

      if (!matchesQuery) return false;

      if (filter == 'Todos') return true;
      if (filter == 'Activo') return u.isActivo;
      if (filter == 'Revocado') return u.isRevocado;
      if (filter == 'Estudiante') return u.rol.contains('Estudiante');
      if (filter == 'Docente') return u.rol.contains('Docente');
      if (filter == 'Coordinador') return u.rol.contains('Coordinador');
      return true;
    }).toList();
  }

  int get cuentasActivasCount => users.where((u) => u.isActivo).length;
  int get docentesCount =>
      users.where((u) => u.rol.toLowerCase().contains('docente')).length;
  int get suspendidosCount => users.where((u) => u.isRevocado).length;

  AdminState copyWith({
    List<AdminUser>? users,
    AdminUser? Function()? selectedUser,
    int? activeTab,
    String? searchQuery,
    String? filter,
    String? adminPhone,
    bool? isLoading,
    String? Function()? errorMessage,
  }) {
    return AdminState(
      users: users ?? this.users,
      selectedUser:
          selectedUser != null ? selectedUser() : this.selectedUser,
      activeTab: activeTab ?? this.activeTab,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      adminPhone: adminPhone ?? this.adminPhone,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class AdminController extends StateNotifier<AdminState> {
  AdminController(this._ref)
      : super(AdminState(users: _initialSeedUsers)) {
    loadUsers();
  }

  final Ref _ref;

  static const List<AdminUser> _initialSeedUsers = [
    AdminUser(
      id: '1001',
      nombre: 'Camilo Andres',
      correo: 'candres@comfenalco.edu.co',
      telefono: '300 123 4567',
      rol: 'Estudiante',
      estado: 'Activo',
    ),
    AdminUser(
      id: '1002',
      nombre: 'Valentina Ruiz',
      correo: 'vruiz@comfenalco.edu.co',
      telefono: '300 234 5678',
      rol: 'Estudiante',
      estado: 'Activo',
    ),
    AdminUser(
      id: '1003',
      nombre: 'Juan Pablo Mora',
      correo: 'jmora@comfenalco.edu.co',
      telefono: '300 345 6789',
      rol: 'Estudiante',
      estado: 'Activo',
    ),
    AdminUser(
      id: '1004',
      nombre: 'Laura Martínez',
      correo: 'lmartinez@comfenalco.edu.co',
      telefono: '300 456 7890',
      rol: 'Docente',
      estado: 'Activo',
    ),
    AdminUser(
      id: '1005',
      nombre: 'Carlos Chavarriaga',
      correo: 'cchavarriaga@comfenalco.edu.co',
      telefono: '300 567 8901',
      rol: 'Docente + Estudiante',
      estado: 'Activo',
    ),
    AdminUser(
      id: '1006',
      nombre: 'Andrés Pérez',
      correo: 'aperez@comfenalco.edu.co',
      telefono: '300 678 9012',
      rol: 'Docente',
      estado: 'Revocado',
    ),
    AdminUser(
      id: '1007',
      nombre: 'Sofía Rojas',
      correo: 'srojas@comfenalco.edu.co',
      telefono: '300 789 0123',
      rol: 'Docente',
      estado: 'Activo',
    ),
    AdminUser(
      id: '1008',
      nombre: 'Ricardo Vélez',
      correo: 'rvelez@comfenalco.edu.co',
      telefono: '300 890 1234',
      rol: 'Coordinador',
      estado: 'Activo',
    ),
  ];

  Future<void> loadUsers() async {
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get<List<dynamic>>('/api/admin/users');
      if (res.data != null && res.data!.isNotEmpty) {
        final fetched = res.data!
            .map((item) => AdminUser.fromJson(item as Map<String, dynamic>))
            .toList();
        state = state.copyWith(users: fetched);
      }
    } catch (e) {
      debugPrint('AdminController: usando datos iniciales locales ($e)');
    }
  }

  void setTab(int index) {
    state = state.copyWith(
      activeTab: index,
      selectedUser: () => null,
    );
  }

  void selectUser(AdminUser user) {
    state = state.copyWith(
      selectedUser: () => user,
      activeTab: 1, // En pestaña usuarios
    );
  }

  void clearSelectedUser() {
    state = state.copyWith(selectedUser: () => null);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  Future<bool> updateUser(AdminUser updated, {String? nuevaContrasena}) async {
    state = state.copyWith(isLoading: true, errorMessage: () => null);

    final currentUsers = List<AdminUser>.from(state.users);
    final index = currentUsers.indexWhere((u) => u.id == updated.id);
    if (index != -1) {
      currentUsers[index] = updated;
    } else {
      currentUsers.add(updated);
    }

    state = state.copyWith(
      users: currentUsers,
      selectedUser: () => null, // Volver a la lista
      isLoading: false,
    );

    // Intentar sincronizar con backend
    try {
      final dio = _ref.read(dioProvider);
      await dio.put('/api/admin/users/${updated.id}', data: {
        'nombre': updated.nombre,
        'correo': updated.correo,
        'telefono': updated.telefono,
        'rol': updated.rol,
        'estado': updated.estado,
        if (nuevaContrasena != null && nuevaContrasena.trim().isNotEmpty)
          'nuevaContrasena': nuevaContrasena.trim(),
      });
    } catch (e) {
      debugPrint('Sincronización remota pendiente: $e');
    }
    return true;
  }

  Future<void> toggleUserAccess(AdminUser user) async {
    final nextState = user.isActivo ? 'Revocado' : 'Activo';
    final updated = user.copyWith(estado: nextState);

    final currentUsers = List<AdminUser>.from(state.users);
    final index = currentUsers.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      currentUsers[index] = updated;
    }

    state = state.copyWith(
      users: currentUsers,
      selectedUser: state.selectedUser?.id == user.id ? () => updated : null,
    );

    try {
      final dio = _ref.read(dioProvider);
      await dio.patch('/api/admin/users/${user.id}/estado',
          queryParameters: {'estado': nextState});
    } catch (e) {
      debugPrint('Sincronización remota estado: $e');
    }
  }

  Future<void> updateAdminPhone(String phone) async {
    state = state.copyWith(adminPhone: phone);
    try {
      final dio = _ref.read(dioProvider);
      await dio.put('/api/admin/perfil/telefono', data: {'telefono': phone});
    } catch (e) {
      debugPrint('Error guardando teléfono admin en backend: $e');
    }
  }
}

final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
  return AdminController(ref);
});
