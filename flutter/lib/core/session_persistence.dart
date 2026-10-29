import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const sessionPersistenceKey = 'remember_signed_in';
const _lastActiveKey = 'transient_session_last_active_at';
const _transientGracePeriod = Duration(minutes: 1);

Future<void> initializeSessionPersistence() async {
  const storage = FlutterSecureStorage();
  final remember = await storage.read(key: sessionPersistenceKey);
  if (remember == 'true') {
    await storage.delete(key: _lastActiveKey);
    return;
  }

  final token = await storage.read(key: 'token');
  if (token == null) {
    await storage.delete(key: _lastActiveKey);
    return;
  }

  final lastActive = await _readLastActive(storage);
  if (lastActive == null || DateTime.now().difference(lastActive) > _transientGracePeriod) {
    await _clearTransientSession(storage);
    return;
  }
  await _writeLastActive(storage);
}

Future<bool> resumeTransientSession() async {
  const storage = FlutterSecureStorage();
  if (await storage.read(key: sessionPersistenceKey) == 'true') return true;
  if (await storage.read(key: 'token') == null) return true;

  final lastActive = await _readLastActive(storage);
  if (lastActive == null || DateTime.now().difference(lastActive) > _transientGracePeriod) {
    await _clearTransientSession(storage);
    return false;
  }
  await _writeLastActive(storage);
  return true;
}

Future<void> markTransientSessionActive() async {
  const storage = FlutterSecureStorage();
  if (await storage.read(key: sessionPersistenceKey) == 'true' ||
      await storage.read(key: 'token') == null) {
    return;
  }
  await _writeLastActive(storage);
}

Future<DateTime?> _readLastActive(FlutterSecureStorage storage) async {
  final raw = await storage.read(key: _lastActiveKey);
  final milliseconds = int.tryParse(raw ?? '');
  return milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds);
}

Future<void> _writeLastActive(FlutterSecureStorage storage) => storage.write(
      key: _lastActiveKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );

Future<void> _clearTransientSession(FlutterSecureStorage storage) async {
  await storage.delete(key: 'token');
  await storage.delete(key: sessionPersistenceKey);
  await storage.delete(key: _lastActiveKey);
}
