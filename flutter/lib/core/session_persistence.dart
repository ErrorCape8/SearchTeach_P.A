import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const sessionPersistenceKey = 'remember_signed_in';

Future<void> initializeSessionPersistence() async {
  const storage = FlutterSecureStorage();
  final remember = await storage.read(key: sessionPersistenceKey);
  if (remember != 'true') await storage.delete(key: 'token');
}
