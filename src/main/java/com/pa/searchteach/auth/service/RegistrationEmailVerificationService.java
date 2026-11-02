package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.exception.AuthException;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.HexFormat;
import java.util.Locale;

@Service
public class RegistrationEmailVerificationService {
	private static final Duration CODE_TTL = Duration.ofMinutes(10);
	private static final String CODE_PREFIX = "searchteach:register:code:";
	private static final String VERIFIED_PREFIX = "searchteach:register:verified:";
	private static final String RESEND_PREFIX = "searchteach:register:resend:";
	private static final String RESET_CODE_PREFIX = "searchteach:password-reset:code:";
	private static final String RESET_VERIFIED_PREFIX = "searchteach:password-reset:verified:";
	private static final String RESET_RESEND_PREFIX = "searchteach:password-reset:resend:";
	private final UserRepository userRepository;
	private final StringRedisTemplate redis;
	private final BrevoEmailService brevo;
	private final SecureRandom random = new SecureRandom();

	public RegistrationEmailVerificationService(UserRepository userRepository, StringRedisTemplate redis,
			BrevoEmailService brevo) {
		this.userRepository = userRepository;
		this.redis = redis;
		this.brevo = brevo;
	}

	public void sendCode(String identifier, String email) {
		User user = matchingStudent(identifier, email);
		Boolean canSend = redis.opsForValue().setIfAbsent(RESEND_PREFIX + identifier, "1", Duration.ofSeconds(60));
		if (!Boolean.TRUE.equals(canSend)) {
			Long wait = redis.getExpire(RESEND_PREFIX + identifier);
			throw new AuthException(HttpStatus.TOO_MANY_REQUESTS,
					"Espera antes de solicitar otro código.", true, Math.max(wait == null ? 60 : wait, 1));
		}
		String code = String.format(Locale.ROOT, "%06d", random.nextInt(1_000_000));
		String normalizedEmail = normalize(user.getCorreo());
		try {
			brevo.sendRegistrationCode(normalizedEmail, code);
			redis.opsForValue().set(CODE_PREFIX + identifier, hash(code) + ":" + normalizedEmail, CODE_TTL);
			redis.delete(VERIFIED_PREFIX + identifier);
		} catch (RuntimeException exception) {
			redis.delete(RESEND_PREFIX + identifier);
			throw exception;
		}
	}

	public void verifyCode(String identifier, String code) {
		String stored = redis.opsForValue().get(CODE_PREFIX + identifier);
		if (stored == null) {
			throw new AuthException(HttpStatus.BAD_REQUEST, "El código venció o no existe. Solicita uno nuevo.", true);
		}
		int separator = stored.indexOf(':');
		if (separator < 0 || !MessageDigest.isEqual(hash(code).getBytes(StandardCharsets.UTF_8),
				stored.substring(0, separator).getBytes(StandardCharsets.UTF_8))) {
			throw new AuthException(HttpStatus.BAD_REQUEST, "El código ingresado no es válido.", true);
		}
		String email = stored.substring(separator + 1);
		redis.opsForValue().set(VERIFIED_PREFIX + identifier, email, CODE_TTL);
		redis.delete(CODE_PREFIX + identifier);
	}

	public void requireVerified(String identifier) {
		String verifiedEmail = redis.opsForValue().get(VERIFIED_PREFIX + identifier);
		if (verifiedEmail == null) {
			throw new AuthException(HttpStatus.BAD_REQUEST,
					"Verifica primero el código enviado a tu correo institucional.", true);
		}
		User user = userRepository.findById(identifier).orElse(null);
		if (user == null || !normalize(user.getCorreo()).equals(verifiedEmail)) {
			redis.delete(VERIFIED_PREFIX + identifier);
			throw new AuthException(HttpStatus.BAD_REQUEST, "El correo institucional cambió. Solicita otro código.", true);
		}
	}

	public void consume(String identifier) {
		redis.delete(VERIFIED_PREFIX + identifier);
	}

	public void sendPasswordResetCode(String identifier, String email) {
		User user = matchingAccount(identifier, email);
		Boolean canSend = redis.opsForValue().setIfAbsent(RESET_RESEND_PREFIX + identifier, "1", Duration.ofSeconds(60));
		if (!Boolean.TRUE.equals(canSend)) {
			Long wait = redis.getExpire(RESET_RESEND_PREFIX + identifier);
			throw new AuthException(HttpStatus.TOO_MANY_REQUESTS,
					"Espera antes de solicitar otro código.", true, Math.max(wait == null ? 60 : wait, 1));
		}
		String code = String.format(Locale.ROOT, "%06d", random.nextInt(1_000_000));
		String normalizedEmail = normalize(user.getCorreo());
		try {
			brevo.sendPasswordResetCode(normalizedEmail, code);
			redis.opsForValue().set(RESET_CODE_PREFIX + identifier, hash(code) + ":" + normalizedEmail, CODE_TTL);
			redis.delete(RESET_VERIFIED_PREFIX + identifier);
		} catch (RuntimeException exception) {
			redis.delete(RESET_RESEND_PREFIX + identifier);
			throw exception;
		}
	}

	public void verifyPasswordResetCode(String identifier, String code) {
		String stored = redis.opsForValue().get(RESET_CODE_PREFIX + identifier);
		if (stored == null) {
			throw new AuthException(HttpStatus.BAD_REQUEST, "El código venció o no existe. Solicita uno nuevo.", true);
		}
		int separator = stored.indexOf(':');
		if (separator < 0 || !MessageDigest.isEqual(hash(code).getBytes(StandardCharsets.UTF_8),
				stored.substring(0, separator).getBytes(StandardCharsets.UTF_8))) {
			throw new AuthException(HttpStatus.BAD_REQUEST, "El código ingresado no es válido.", true);
		}
		redis.opsForValue().set(RESET_VERIFIED_PREFIX + identifier, stored.substring(separator + 1), CODE_TTL);
		redis.delete(RESET_CODE_PREFIX + identifier);
	}

	public void requirePasswordResetVerified(String identifier) {
		String email = redis.opsForValue().get(RESET_VERIFIED_PREFIX + identifier);
		if (email == null) {
			throw new AuthException(HttpStatus.BAD_REQUEST,
					"Verifica primero el código enviado a tu correo institucional.", true);
		}
		User user = userRepository.findById(identifier).orElse(null);
		if (user == null || !normalize(user.getCorreo()).equals(email)) {
			redis.delete(RESET_VERIFIED_PREFIX + identifier);
			throw new AuthException(HttpStatus.BAD_REQUEST, "El correo institucional cambió. Solicita otro código.", true);
		}
	}

	public void consumePasswordReset(String identifier) {
		redis.delete(RESET_VERIFIED_PREFIX + identifier);
	}

	private User matchingStudent(String identifier, String email) {
		User user = userRepository.findById(identifier).orElse(null);
		if (user == null || user.getCorreo() == null || user.getCorreo().isBlank()
				|| !normalize(user.getCorreo()).equals(normalize(email))) {
			throw new AuthException(HttpStatus.NOT_FOUND,
					"No encontramos una cuenta con esa identificación y correo institucional.", true);
		}
		if (user.getPasswordHash() != null && !user.getPasswordHash().isBlank()) {
			throw new AuthException(HttpStatus.CONFLICT, "Esta cuenta ya tiene contraseña. Inicia sesión.", false);
		}
		return user;
	}

	private User matchingAccount(String identifier, String email) {
		User user = userRepository.findById(identifier).orElse(null);
		if (user == null || user.getCorreo() == null || user.getCorreo().isBlank()
				|| !normalize(user.getCorreo()).equals(normalize(email))) {
			throw new AuthException(HttpStatus.NOT_FOUND,
					"No encontramos una cuenta con esa identificación y correo institucional.", true);
		}
		if (user.getPasswordHash() == null || user.getPasswordHash().isBlank()) {
			throw new AuthException(HttpStatus.CONFLICT, "Esta cuenta aún no tiene contraseña. Regístrate.", false);
		}
		return user;
	}

	private String normalize(String email) {
		return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
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
