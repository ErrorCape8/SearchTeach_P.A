package com.pa.searchteach.auth.service;

import java.util.Locale;

import com.pa.searchteach.auth.exception.AuthException;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Códigos por correo para el registro inicial y para recuperar la contraseña (sin sesión). */
@Service
public class RegistrationEmailVerificationService {

	private static final String REGISTER = "register";
	private static final String PASSWORD_RESET = "password-reset";
	private static final String NOT_VERIFIED = "Verifica primero el código enviado a tu correo institucional.";

	private final UserRepository userRepository;
	private final VerificationCodeStore codes;
	private final BrevoEmailService brevo;

	public RegistrationEmailVerificationService(UserRepository userRepository, VerificationCodeStore codes,
			BrevoEmailService brevo) {
		this.userRepository = userRepository;
		this.codes = codes;
		this.brevo = brevo;
	}

	public void sendCode(String identifier, String email) {
		User user = matchingStudent(identifier, email);
		String recipient = normalize(user.getCorreo());
		codes.issue(REGISTER, identifier, recipient, code -> brevo.sendRegistrationCode(recipient, code));
	}

	public void verifyCode(String identifier, String code) {
		codes.verify(REGISTER, identifier, code);
	}

	public void requireVerified(String identifier) {
		requireVerifiedEmail(REGISTER, identifier);
	}

	public void consume(String identifier) {
		codes.consume(REGISTER, identifier);
	}

	public void sendPasswordResetCode(String identifier, String email) {
		User user = matchingAccount(identifier, email);
		String recipient = normalize(user.getCorreo());
		codes.issue(PASSWORD_RESET, identifier, recipient, code -> brevo.sendPasswordResetCode(recipient, code));
	}

	public void verifyPasswordResetCode(String identifier, String code) {
		codes.verify(PASSWORD_RESET, identifier, code);
	}

	public void requirePasswordResetVerified(String identifier) {
		requireVerifiedEmail(PASSWORD_RESET, identifier);
	}

	public void consumePasswordReset(String identifier) {
		codes.consume(PASSWORD_RESET, identifier);
	}

	private void requireVerifiedEmail(String namespace, String identifier) {
		String verifiedEmail = codes.requireVerified(namespace, identifier, NOT_VERIFIED);
		User user = userRepository.findById(identifier).orElse(null);
		if (user == null || !normalize(user.getCorreo()).equals(verifiedEmail)) {
			codes.consume(namespace, identifier);
			throw new AuthException(HttpStatus.BAD_REQUEST, "El correo institucional cambió. Solicita otro código.", true);
		}
	}

	private User matchingStudent(String identifier, String email) {
		User user = findByIdentifierAndEmail(identifier, email);
		if (user.getPasswordHash() != null && !user.getPasswordHash().isBlank()) {
			throw new AuthException(HttpStatus.CONFLICT, "Esta cuenta ya tiene contraseña. Inicia sesión.", false);
		}
		return user;
	}

	private User matchingAccount(String identifier, String email) {
		User user = findByIdentifierAndEmail(identifier, email);
		if (user.getPasswordHash() == null || user.getPasswordHash().isBlank()) {
			throw new AuthException(HttpStatus.CONFLICT, "Esta cuenta aún no tiene contraseña. Regístrate.", false);
		}
		return user;
	}

	private User findByIdentifierAndEmail(String identifier, String email) {
		User user = userRepository.findById(identifier).orElse(null);
		if (user == null || user.getCorreo() == null || user.getCorreo().isBlank()
				|| !normalize(user.getCorreo()).equals(normalize(email))) {
			throw new AuthException(HttpStatus.NOT_FOUND,
					"No encontramos una cuenta con esa identificación y correo institucional.", true);
		}
		return user;
	}

	private String normalize(String email) {
		return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
	}
}
