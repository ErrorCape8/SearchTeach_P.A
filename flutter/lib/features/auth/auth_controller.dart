import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';

/// Controlador: guarda el estado (cargando / error) y llama al repositorio.
/// La pantalla solo hace ref.watch(...) y pinta; no sabe nada de Dio ni de la API.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> login(String id, String password) =>
      _run(() => ref.read(authRepositoryProvider).login(id, password));

  Future<bool> register(String id, String password) =>
      _run(() => ref.read(authRepositoryProvider).register(id, password));

  Future<bool> verifyRegistration(String id) =>
      _run(() => ref.read(authRepositoryProvider).verifyRegistration(id));

  /// Borra el error/cargando al entrar o salir de una pantalla.
  void reset() => state = const AsyncData(null);

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }

  String? get errorMessage {
    final e = state.error;
    return e is AuthFailure
        ? e.message
        : (e == null ? null : 'Error inesperado.');
  }
}

final authControllerProvider =
    AsyncNotifierProvider.autoDispose<AuthController, void>(AuthController.new);
