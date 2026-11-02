package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.exception.AuthException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;
import org.springframework.web.client.RestClientException;

import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;

@Service
public class BrevoEmailService {
	private static final Logger LOGGER = Logger.getLogger(BrevoEmailService.class.getName());
	private final String apiKey;
	private final String senderEmail;
	private final String senderName;
	private final RestClient restClient;

	public BrevoEmailService(
			@Value("${app.brevo.api-key:}") String apiKey,
			@Value("${app.brevo.sender-email:}") String senderEmail,
			@Value("${app.brevo.sender-name:SearchTeach}") String senderName) {
		this.apiKey = apiKey;
		this.senderEmail = senderEmail;
		this.senderName = senderName;
		this.restClient = RestClient.builder().baseUrl("https://api.brevo.com").build();
	}

	public void sendRegistrationCode(String recipient, String code) {
		sendCode(recipient, code, "Código de verificación de SearchTeach",
				"Tu código de verificación de SearchTeach es ");
	}

	public void sendPasswordResetCode(String recipient, String code) {
		sendCode(recipient, code, "Código para restablecer tu contraseña de SearchTeach",
				"Tu código para restablecer la contraseña de SearchTeach es ");
	}

	private void sendCode(String recipient, String code, String subject, String messagePrefix) {
		if (apiKey.isBlank() || senderEmail.isBlank()) {
			throw new AuthException(HttpStatus.SERVICE_UNAVAILABLE,
					"El envío de correo aún no está configurado en el servidor.", false);
		}
		Map<String, Object> body = Map.of(
				"sender", Map.of("name", senderName, "email", senderEmail),
				"to", List.of(Map.of("email", recipient)),
				"subject", subject,
				"textContent", messagePrefix + code
						+ ". Vence en 10 minutos. Si no solicitaste este código, ignora este mensaje.");
		try {
			restClient.post().uri("/v3/smtp/email")
					.header("api-key", apiKey)
					.contentType(MediaType.APPLICATION_JSON)
					.body(body)
					.retrieve().toBodilessEntity();
		} catch (RestClientResponseException exception) {
			String response = exception.getResponseBodyAsString()
					.replaceAll("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "[email redacted]");
			LOGGER.log(Level.WARNING, "Brevo rechazó el envío (HTTP {0}): {1}",
					new Object[] { exception.getStatusCode().value(), response });
			throw new AuthException(HttpStatus.BAD_GATEWAY,
					"No se pudo enviar el correo de verificación. Inténtalo de nuevo.", true);
		} catch (RestClientException exception) {
			LOGGER.log(Level.WARNING, "No fue posible conectar con la API de Brevo: {0}", exception.getMessage());
			throw new AuthException(HttpStatus.BAD_GATEWAY,
					"No se pudo enviar el correo de verificación. Inténtalo de nuevo.", true);
		}
	}
}
