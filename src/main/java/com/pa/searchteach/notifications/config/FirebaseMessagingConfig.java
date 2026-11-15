package com.pa.searchteach.notifications.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(name = "app.firebase.enabled", havingValue = "true")
public class FirebaseMessagingConfig {
    /**
     * Usa el JSON de la cuenta de servicio indicado en FIREBASE_SERVICE_ACCOUNT_FILE.
     * Si la variable no está definida, cae a las credenciales por defecto de Google
     * (GOOGLE_APPLICATION_CREDENTIALS).
     */
    @Bean
    FirebaseApp searchTeachFirebaseApp(@Value("${FIREBASE_SERVICE_ACCOUNT_FILE:}") String archivoCuenta)
            throws IOException {
        if (!FirebaseApp.getApps().isEmpty()) return FirebaseApp.getInstance();
        GoogleCredentials credenciales;
        if (archivoCuenta == null || archivoCuenta.isBlank()) {
            credenciales = GoogleCredentials.getApplicationDefault();
        } else {
            try (InputStream entrada = new FileInputStream(archivoCuenta.trim())) {
                credenciales = GoogleCredentials.fromStream(entrada);
            }
        }
        FirebaseOptions options = FirebaseOptions.builder().setCredentials(credenciales).build();
        return FirebaseApp.initializeApp(options);
    }

    @Bean
    FirebaseMessaging firebaseMessaging(FirebaseApp searchTeachFirebaseApp) {
        return FirebaseMessaging.getInstance(searchTeachFirebaseApp);
    }
}
