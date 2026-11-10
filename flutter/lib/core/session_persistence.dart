import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const sessionPersistenceKey = 'remember_signed_in';
const _legacyLastActiveKey = 'transient_session_last_active_at';

Future<void> initializeSessionPersistence() async {
  const storage = FlutterSecureStorage();
  await storage.delete(key: _legacyLastActiveKey);
  if (await storage.read(key: sessionPersistenceKey) != 'true') {
    await storage.delete(key: 'token');
  }
}
