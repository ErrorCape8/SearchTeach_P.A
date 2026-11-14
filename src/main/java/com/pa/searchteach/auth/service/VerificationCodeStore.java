package com.pa.searchteach.auth.service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.HexFormat;
import java.util.Locale;
import java.util.function.Consumer;

import com.pa.searchteach.auth.exception.AuthException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Códigos de seis dígitos de un solo uso guardados en Redis.
 *
 * <p>Cada flujo se identifica con un {@code namespace} (registro, recuperación, perfil...) y una
 * {@code key} (normalmente la identificación del usuario). El código viaja por correo; en Redis
 * solo se guarda su hash.
 */
@Component
public class VerificationCodeStore {

	private static final Duration CODE_TTL = Duration.ofMinutes(10);
	private static final Duration RESEND_INTERVAL = Duration.ofSeconds(60);
	private static final int MAX_WRONG_ATTEMPTS = 5;

	private final StringRedisTemplate redis;
	private final SecureRandom random = new SecureRandom();

	public VerificationCodeStore(StringRedisTemplate redis) {
		this.redis = redis;
	}

	/**
	 * Genera un código nuevo, lo entrega con {@code sender} y lo deja pendiente de verificación.
	 *
	 * @param payload dato que queda asociado al código (el correo al que se envió)
	 */
	public void issue(String namespace, String key, String payload, Consumer<String> sender) {
		String resendKey = redisKey(namespace, "resend", key);
		Boolean canSend = redis.opsForValue().setIfAbsent(resendKey, "1", RESEND_INTERVAL);
		if (!Boolean.TRUE.equals(canSend)) {
			Long wait = redis.getExpire(resendKey);
			throw new AuthException(HttpStatus.TOO_MANY_REQUESTS,
					"Espera antes de solicitar otro código.", true, Math.max(wait == null ? 60 : wait, 1));
		}
		String code = String.format(Locale.ROOT, "%06d", random.nextInt(1_000_000));
		try {
			sender.accept(code);
		} catch (RuntimeException exception) {
			redis.delete(resendKey);
			throw exception;
		}
		redis.opsForValue().set(redisKey(namespace, "code", key), hash(code) + ":" + payload, CODE_TTL);
		redis.delete(redisKey(namespace, "verified", key));
		redis.delete(redisKey(namespace, "attempts", key));
	}

	/** Comprueba el código; si es correcto lo marca como verificado y devuelve su payload. */
	public String verify(String namespace, String key, String code) {
		String codeKey = redisKey(namespace, "code", key);
		String stored = redis.opsForValue().get(codeKey);
		if (stored == null) {
			throw new AuthException(HttpStatus.BAD_REQUEST, "El código venció o no existe. Solicita uno nuevo.", true);
		}
		int separator = stored.indexOf(':');
		boolean matches = separator >= 0 && MessageDigest.isEqual(
				hash(code).getBytes(StandardCharsets.UTF_8),
				stored.substring(0, separator).getBytes(StandardCharsets.UTF_8));
		if (!matches) {
			registerWrongAttempt(namespace, key, codeKey);
			throw new AuthException(HttpStatus.BAD_REQUEST, "El código ingresado no es válido.", true);
		}
		String payload = stored.substring(separator + 1);
		redis.opsForValue().set(redisKey(namespace, "verified", key), payload, CODE_TTL);
		redis.delete(codeKey);
		redis.delete(redisKey(namespace, "attempts", key));
		return payload;
	}

	/** Devuelve el payload de un código ya verificado o falla si no hay verificación vigente. */
	public String requireVerified(String namespace, String key, String missingMessage) {
		String payload = redis.opsForValue().get(redisKey(namespace, "verified", key));
		if (payload == null) {
			throw new AuthException(HttpStatus.BAD_REQUEST, missingMessage, true);
		}
		return payload;
	}

	/** Descarta la verificación para que no pueda reutilizarse. */
	public void consume(String namespace, String key) {
		redis.delete(redisKey(namespace, "verified", key));
	}

	private void registerWrongAttempt(String namespace, String key, String codeKey) {
		String attemptsKey = redisKey(namespace, "attempts", key);
		Long attempts = redis.opsForValue().increment(attemptsKey);
		if (attempts != null && attempts == 1) {
			redis.expire(attemptsKey, CODE_TTL);
		}
		if (attempts != null && attempts >= MAX_WRONG_ATTEMPTS) {
			redis.delete(codeKey);
			redis.delete(attemptsKey);
		}
	}

	private String redisKey(String namespace, String kind, String key) {
		return "searchteach:" + namespace + ":" + kind + ":" + key;
	}

	private String hash(String value) {
		try {
			return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
					.digest(value.getBytes(StandardCharsets.UTF_8)));
		} catch (Exception exception) {
			throw new IllegalStateException("SHA-256 no está disponible.", exception);
		}
	}
}
