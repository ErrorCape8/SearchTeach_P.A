# Notificaciones de SearchTeach

La bandeja com?n y los avisos de tutor?as se guardan en MongoDB y est?n disponibles para cualquier cuenta autenticada en `/api/notificaciones`. El env?o a dispositivos usa Firebase Cloud Messaging (FCM).

## Activar FCM

1. Crear o seleccionar un proyecto Firebase y registrar la aplicaci?n Android y la aplicaci?n web.
2. En Firebase Console, generar una clave de cuenta de servicio y configurar `GOOGLE_APPLICATION_CREDENTIALS` en el entorno del backend. Activar el env?o con `FIREBASE_PUSH_ENABLED=true`.
3. Copiar la configuraci?n web de Firebase y la clave VAPID de Cloud Messaging. Configurar la clave p?blica del cliente al compilar Flutter con `--dart-define`:

   - `FIREBASE_API_KEY`
   - `FIREBASE_APP_ID`
   - `FIREBASE_MESSAGING_SENDER_ID`
   - `FIREBASE_PROJECT_ID`
   - `FIREBASE_AUTH_DOMAIN`
   - `FIREBASE_STORAGE_BUCKET`
   - `FIREBASE_WEB_VAPID_KEY`

4. Reemplazar los valores `FIREBASE_*` de `flutter/web/firebase-messaging-sw.js` por la configuraci?n web p?blica de Firebase.
5. Servir la web mediante HTTPS (o localhost durante desarrollo), instalarla y pedir al usuario que active notificaciones desde la bandeja. En Android, conceder el permiso del sistema.

La clave privada de cuenta de servicio se configura solo en el backend; nunca debe incluirse en Flutter ni en el repositorio. Si FCM no est? configurado, la bandeja y las notificaciones internas contin?an funcionando.
