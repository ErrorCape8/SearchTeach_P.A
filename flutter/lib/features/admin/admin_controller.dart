import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'models/admin_user.dart';

final adminPendingCertificationsProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final response = await ref
      .read(dioProvider)
      .get<List<dynamic>>('/api/admin/certificaciones');
  return (response.data ?? const [])
      .whereType<Map<String, dynamic>>()
      .where((item) => item['estado'] == 'PENDIENTE')
      .length;
});

class AdminStats {
  const AdminStats({
    required this.cuentasTotal,
    required this.cuentasActivas,
    required this.docentes,
    required this.suspendidos,
  });

  final int cuentasTotal;
  final int cuentasActivas;
  final int docentes;
  final int suspendidos;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    int readCount(String key) {
      final value = json[key];
      if (value is! num || value < 0) {
        throw FormatException('El contador "$key" no es válido.');
      }
      return value.toInt();
    }

    return AdminStats(
      cuentasTotal: readCount('cuentasTotal'),
      cuentasActivas: readCount('cuentasActivas'),
      docentes: readCount('docentes'),
      suspendidos: readCount('suspendidos'),
    );
  }
}

class AdminProfile {
  const AdminProfile({
    required this.nombre,
    required this.rol,
    required this.telefono,
    required this.correo,
    required this.documento,
    required this.programa,
  });

  final String nombre;
  final String rol;
  final String telefono;
  final String correo;
  final String documento;
  final String programa;

  factory AdminProfile.fromJson(Map<String, dynamic> json) {
    String readValue(String key) {
      final value = json[key];
      if (value is! String) {
        throw FormatException('El dato de perfil "$key" no es válido.');
      }
      return value;
    }

    return AdminProfile(
      nombre: readValue('nombre'),
      rol: readValue('rol'),
      telefono: readValue('telefono'),
      correo: readValue('correo'),
      documento: readValue('documento'),
      programa: readValue('programa'),
    );
  }

  AdminProfile copyWith({String? telefono}) => AdminProfile(
        nombre: nombre,
        rol: rol,
        telefono: telefono ?? this.telefono,
        correo: correo,
        documento: documento,
        programa: programa,
      );
}

class AdminState {
  const AdminState({
    this.users = const [],
    this.selectedUser,
    this.isEditingSelectedUser = false,
    this.activeTab = 0,
    this.usersPage = 0,
    this.searchQuery = '',
    this.filter = 'Todos',
    this.stats,
    this.adminProfile,
    this.isLoadingUsers = true,
    this.isLoadingStats = true,
    this.isLoadingProfile = true,
    this.isSaving = false,
    this.usersError,
    this.statsError,
    this.profileError,
    this.errorMessage,
  });

  final List<AdminUser> users;
  final AdminUser? selectedUser;
  final bool isEditingSelectedUser;
  final int activeTab;
  final int usersPage;
  final String searchQuery;
  final String filter;
  final AdminStats? stats;
  final AdminProfile? adminProfile;
  final bool isLoadingUsers;
  final bool isLoadingStats;
  final bool isLoadingProfile;
  final bool isSaving;
  final String? usersError;
  final String? statsError;
  final String? profileError;
  final String? errorMessage;

  List<AdminUser> get filteredUsers {
    return users.where((user) {
      final query = searchQuery.toLowerCase();
      final matchesQuery = query.isEmpty ||
          user.nombre.toLowerCase().contains(query) ||
          user.id.toLowerCase().contains(query) ||
          user.correo.toLowerCase().contains(query) ||
          user.rol.toLowerCase().contains(query) ||
          user.carrera.toLowerCase().contains(query);

      if (!matchesQuery) return false;
      if (filter == 'Todos') return true;
      if (filter == 'Activo') return user.isActivo;
      if (filter == 'Revocado') return user.isRevocado;
      final role = user.rol.toLowerCase();
      if (filter == 'Estudiante') return role.contains('estudiante');
      if (filter == 'Docente') return role.contains('docente');
      if (filter == 'Coordinador') return role.contains('coordinador');
      if (filter == 'Líder de programas') {
        return role.contains('líder') || role.contains('lider');
      }
      return true;
    }).toList();
  }

  AdminState copyWith({
    List<AdminUser>? users,
    AdminUser? Function()? selectedUser,
    bool? isEditingSelectedUser,
    int? activeTab,
    int? usersPage,
    String? searchQuery,
    String? filter,
    AdminStats? Function()? stats,
    AdminProfile? Function()? adminProfile,
    bool? isLoadingUsers,
    bool? isLoadingStats,
    bool? isLoadingProfile,
    bool? isSaving,
    String? Function()? usersError,
    String? Function()? statsError,
    String? Function()? profileError,
    String? Function()? errorMessage,
  }) {
    return AdminState(
      users: users ?? this.users,
      selectedUser: selectedUser != null ? selectedUser() : this.selectedUser,
      isEditingSelectedUser:
          isEditingSelectedUser ?? this.isEditingSelectedUser,
      activeTab: activeTab ?? this.activeTab,
      usersPage: usersPage ?? this.usersPage,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      stats: stats != null ? stats() : this.stats,
      adminProfile: adminProfile != null ? adminProfile() : this.adminProfile,
      isLoadingUsers: isLoadingUsers ?? this.isLoadingUsers,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      isSaving: isSaving ?? this.isSaving,
      usersError: usersError != null ? usersError() : this.usersError,
      statsError: statsError != null ? statsError() : this.statsError,
      profileError: profileError != null ? profileError() : this.profileError,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

class AdminController extends StateNotifier<AdminState> {
  AdminController(this._ref) : super(const AdminState()) {
    loadUsers();
    loadStats();
    loadProfile();
  }

  final Ref _ref;

  Future<void> loadUsers() async {
    state = state.copyWith(isLoadingUsers: true, usersError: () => null);
    try {
      final response =
          await _ref.read(dioProvider).get<List<dynamic>>('/api/admin/users');
      final data = response.data;
      if (data == null) {
        throw const FormatException(
            'El servidor no devolvió la lista de usuarios.');
      }
      final users = data.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException(
              'El servidor devolvió un usuario inválido.');
        }
        return AdminUser.fromJson(item);
      }).toList(growable: false);
      state = state.copyWith(users: users, isLoadingUsers: false);
    } on DioException catch (error) {
      state = state.copyWith(
        isLoadingUsers: false,
        usersError: () => _apiError(error),
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        isLoadingUsers: false,
        usersError: () => error.message,
      );
    }
  }

  Future<void> loadStats() async {
    state = state.copyWith(isLoadingStats: true, statsError: () => null);
    try {
      final response = await _ref
          .read(dioProvider)
          .get<Map<String, dynamic>>('/api/admin/stats');
      final data = response.data;
      if (data == null) {
        throw const FormatException('El servidor no devolvió las métricas.');
      }
      state = state.copyWith(
        stats: () => AdminStats.fromJson(data),
        isLoadingStats: false,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isLoadingStats: false,
        statsError: () => _apiError(error),
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        isLoadingStats: false,
        statsError: () => error.message,
      );
    }
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoadingProfile: true, profileError: () => null);
    try {
      final response = await _ref
          .read(dioProvider)
          .get<Map<String, dynamic>>('/api/admin/perfil');
      final data = response.data;
      if (data == null) {
        throw const FormatException('El servidor no devolvió el perfil de TI.');
      }

      state = state.copyWith(
        adminProfile: () => AdminProfile.fromJson(data),
        isLoadingProfile: false,
      );
    } on DioException catch (error) {
      state = state.copyWith(
        isLoadingProfile: false,
        profileError: () => _apiError(error),
      );
    } on FormatException catch (error) {
      state = state.copyWith(
        isLoadingProfile: false,
        profileError: () => error.message,
      );
    }
  }

  Future<void> refreshDashboard() async {
    _ref.invalidate(adminPendingCertificationsProvider);
    await Future.wait([
      loadUsers(),
      loadStats(),
      loadProfile(),
    ]);
  }

  Future<bool> updateAdminPhone(String phone) async {
    try {
      await _ref.read(dioProvider).put<void>(
        '/api/admin/perfil/telefono',
        data: {'telefono': phone},
      );
      await loadProfile();
      return true;
    } on DioException catch (error) {
      state = state.copyWith(profileError: () => _apiError(error));
      return false;
    }
  }

  String _apiError(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'No se pudieron cargar los datos desde el servidor. Comprueba tu conexión e inténtalo de nuevo.';
  }

  void setTab(int index) {
    state = state.copyWith(
      activeTab: index,
      selectedUser: () => null,
      isEditingSelectedUser: false,
    );
  }

  void selectUser(AdminUser user) {
    state = state.copyWith(
      selectedUser: () => user,
      isEditingSelectedUser: false,
      activeTab: 1,
    );
  }

  void editSelectedUser() {
    if (state.selectedUser == null) return;
    state = state.copyWith(isEditingSelectedUser: true);
  }

  void clearSelectedUser() {
    state = state.copyWith(
      selectedUser: () => null,
      isEditingSelectedUser: false,
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(
      searchQuery: query,
      usersPage: query.trim().isEmpty ? state.usersPage : 0,
    );
  }

  void setUsersPage(int page) {
    state = state.copyWith(usersPage: page);
  }

  void setFilter(String filter) {
    state = state.copyWith(filter: filter);
  }

  Future<bool> updateUser(AdminUser updated, {String? nuevaContrasena}) async {
    state = state.copyWith(isSaving: true, errorMessage: () => null);
    try {
      final response = await _ref.read(dioProvider).put<Map<String, dynamic>>(
        '/api/admin/users/${updated.id}',
        data: {
          'nombre': updated.nombre,
          'correo': updated.correo,
          'telefono': updated.telefono,
          'rol': updated.rol,
          'estado': updated.estado,
          'carrera': updated.carrera,
          if (updated.rol.toLowerCase().contains('estudiante'))
            'semestre': updated.semestre,
          'titulosAcademicos': updated.titulosAcademicos,
          'materiasPrincipales': updated.materiasPrincipales,
          if (nuevaContrasena != null && nuevaContrasena.trim().isNotEmpty)
            'nuevaContrasena': nuevaContrasena.trim(),
        },
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException(
            'El servidor no confirmó los cambios del usuario.');
      }
      final savedUser = AdminUser.fromJson(data);
      final users = List<AdminUser>.from(state.users);
      final index = users.indexWhere((user) => user.id == savedUser.id);
      if (index == -1) {
        users.add(savedUser);
      } else {
        users[index] = savedUser;
      }
      state = state.copyWith(
        users: users,
        selectedUser: () => null,
        isSaving: false,
      );
      await loadStats();
      return true;
    } on DioException catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => _apiError(error),
      );
      return false;
    } on FormatException catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: () => error.message,
      );
      return false;
    }
  }

  Future<void> toggleUserAccess(AdminUser user) async {
    final nextState = user.isActivo ? 'Revocado' : 'Activo';
    try {
      final response = await _ref.read(dioProvider).patch<Map<String, dynamic>>(
        '/api/admin/users/${user.id}/estado',
        queryParameters: {'estado': nextState},
      );
      final data = response.data;
      if (data == null) {
        throw const FormatException(
            'El servidor no confirmó el cambio de acceso.');
      }
      final savedUser = AdminUser.fromJson(data);
      final users = List<AdminUser>.from(state.users);
      final index = users.indexWhere((item) => item.id == savedUser.id);
      if (index != -1) users[index] = savedUser;
      state = state.copyWith(
        users: users,
        selectedUser:
            state.selectedUser?.id == savedUser.id ? () => savedUser : null,
      );
      await loadStats();
    } on DioException catch (error) {
      state = state.copyWith(errorMessage: () => _apiError(error));
    } on FormatException catch (error) {
      state = state.copyWith(errorMessage: () => error.message);
    }
  }
}

final adminControllerProvider =
    StateNotifierProvider<AdminController, AdminState>((ref) {
  return AdminController(ref);
});
