package com.pa.searchteach.users.service;

import java.util.Locale;

import com.pa.searchteach.auth.exception.AuthException;
import com.pa.searchteach.auth.service.BrevoEmailService;
import com.pa.searchteach.auth.service.VerificationCodeStore;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Código de seis dígitos que se envía al correo del perfil antes de permitir cambiar la
 * contraseña o agregar/cambiar el teléfono.
 *
 * <p>Flujo: {@link #enviarCodigo} → {@link #verificarCodigo} → {@link #exigirVerificado}
 * (justo antes de aplicar el cambio) → {@link #consumir}.
 */
@Service
public class PerfilVerificacionService {

	public enum Proposito {
		CONTRASENA("profile-password"),
		TELEFONO("profile-phone");

		private final String namespace;

		Proposito(String namespace) {
			this.namespace = namespace;
		}
	}

	private final CuentaPerfilService cuentas;
	private final VerificationCodeStore codes;
	private final BrevoEmailService brevo;

	public PerfilVerificacionService(
			CuentaPerfilService cuentas, VerificationCodeStore codes, BrevoEmailService brevo) {
		this.cuentas = cuentas;
		this.codes = codes;
		this.brevo = brevo;
	}

	/** Envía el código al correo del perfil y devuelve ese correo enmascarado. */
	public String enviarCodigo(String usuarioId, Proposito proposito) {
		String correo = normalizar(cuentas.correoDe(usuarioId));
		codes.issue(proposito.namespace, usuarioId, correo, code -> {
			if (proposito == Proposito.CONTRASENA) {
				brevo.sendPasswordChangeCode(correo, code);
			} else {
				brevo.sendPhoneChangeCode(correo, code);
			}
		});
		return enmascarar(correo);
	}

	public void verificarCodigo(String usuarioId, Proposito proposito, String code) {
		codes.verify(proposito.namespace, usuarioId, code);
	}

	public void exigirVerificado(String usuarioId, Proposito proposito) {
		String verificado = codes.requireVerified(proposito.namespace, usuarioId,
				"Confirma primero el código que enviamos al correo de tu perfil.");
		if (!normalizar(cuentas.correoDe(usuarioId)).equals(verificado)) {
			codes.consume(proposito.namespace, usuarioId);
			throw new AuthException(HttpStatus.BAD_REQUEST, "El correo de tu perfil cambió. Solicita otro código.", true);
		}
	}

	public void consumir(String usuarioId, Proposito proposito) {
		codes.consume(proposito.namespace, usuarioId);
	}

	private String normalizar(String correo) {
		return correo.trim().toLowerCase(Locale.ROOT);
	}

	private String enmascarar(String correo) {
		int arroba = correo.indexOf('@');
		if (arroba <= 0) {
			return "***";
		}
		int visibles = Math.min(2, Math.max(1, arroba - 1));
		return correo.substring(0, visibles) + "***" + correo.substring(arroba);
	}
}
