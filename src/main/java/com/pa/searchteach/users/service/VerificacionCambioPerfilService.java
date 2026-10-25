package com.pa.searchteach.users.service;

import java.nio.charset.StandardCharsets;
import java.net.URI;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Locale;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.it.model.ItAdmin;
import com.pa.searchteach.it.repository.ItAdminRepository;
import com.pa.searchteach.users.dto.SolicitudCambioPerfil;
import com.pa.searchteach.users.model.CambioPerfilPendiente;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.CambioPerfilPendienteRepositorio;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.server.ResponseStatusException;

@Service
public class VerificacionCambioPerfilService {
	private static final int MAX_INTENTOS = 5;
	private static final int VIGENCIA_MINUTOS = 10;
	private static final int ESPERA_REENVIO_SEGUNDOS = 60;
	private final UserRepository userRepository;
	private final ItAdminRepository itAdminRepository;
	private final CoordinatorRepository coordinatorRepository;
	private final CambioPerfilPendienteRepositorio cambios;
	private final PasswordEncoder passwordEncoder;
	private final RestClient restClient;
	private final String googleScriptUrl;
	private final String googleScriptToken;
	private final SecureRandom random = new SecureRandom();

	public VerificacionCambioPerfilService(
			UserRepository userRepository,
			ItAdminRepository itAdminRepository,
			CoordinatorRepository coordinatorRepository,
			CambioPerfilPendienteRepositorio cambios,
			PasswordEncoder passwordEncoder,
			@Value("${app.mail.google-script.url:}") String googleScriptUrl,
			@Value("${app.mail.google-script.token:}") String googleScriptToken) {
		this.userRepository = userRepository;
		this.itAdminRepository = itAdminRepository;
		this.coordinatorRepository = coordinatorRepository;
		this.cambios = cambios;
		this.passwordEncoder = passwordEncoder;
		this.restClient = RestClient.create();
		this.googleScriptUrl = googleScriptUrl;
		this.googleScriptToken = googleScriptToken;
	}

	public void solicitar(String usuarioId, SolicitudCambioPerfil solicitud) {
		Cuenta cuenta = buscarCuenta(usuarioId);
		if (cuenta.correo() == null || cuenta.correo().isBlank()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Tu cuenta no tiene un correo registrado para recibir el código de seguridad.");
		}
		String correoNuevo = limpiar(solicitud.correo());
		String telefonoNuevo = limpiar(solicitud.telefono());
		String contrasenaNueva = solicitud.nuevaContrasena();
		if (correoNuevo == null && telefonoNuevo == null && (contrasenaNueva == null || contrasenaNueva.isBlank())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indica al menos un dato que quieras cambiar.");
		}
		if (correoNuevo != null) {
			correoNuevo = correoNuevo.toLowerCase(Locale.ROOT);
			if (!correoNuevo.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Escribe un correo electrónico válido.");
			}
			validarCorreoDisponible(correoNuevo, usuarioId);
		}
		if (telefonoNuevo != null && !telefonoNuevo.matches("[0-9+() .-]{7,30}")) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Escribe un número de teléfono válido.");
		}
		String contrasenaHashNueva = null;
		if (contrasenaNueva != null && !contrasenaNueva.isBlank()) {
			if (contrasenaNueva.length() < 8 || contrasenaNueva.getBytes(StandardCharsets.UTF_8).length > 72) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"La nueva contraseña debe tener al menos 8 caracteres y máximo 72 bytes.");
			}
			contrasenaHashNueva = passwordEncoder.encode(contrasenaNueva);
		}
		LocalDateTime ahora = LocalDateTime.now();
		cambios.findById(usuarioId).ifPresent(anterior -> {
			if (anterior.expiraEn().isAfter(ahora)
					&& anterior.creadoEn().plusSeconds(ESPERA_REENVIO_SEGUNDOS).isAfter(ahora)) {
				throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
						"Espera un minuto antes de solicitar otro código.");
			}
			cambios.delete(anterior);
		});
		if (googleScriptUrl == null || googleScriptUrl.isBlank()
				|| googleScriptToken == null || googleScriptToken.isBlank()) {
			throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
					"El envío de correo no está configurado en este momento.");
		}
		String codigo = String.format(Locale.ROOT, "%06d", random.nextInt(1_000_000));
		CambioPerfilPendiente cambio = new CambioPerfilPendiente(
				usuarioId, passwordEncoder.encode(codigo), correoNuevo, telefonoNuevo,
				contrasenaHashNueva, 0, ahora, ahora.plusMinutes(VIGENCIA_MINUTOS));
		cambios.save(cambio);
		try {
			ResponseEntity<String> respuesta = restClient.post()
					.uri(googleScriptUrl)
					.body(java.util.Map.of(
							"token", googleScriptToken,
							"to", cuenta.correo(),
							"code", codigo))
					.retrieve()
					.toEntity(String.class);
			String cuerpo = respuesta.getBody();
			if (respuesta.getStatusCode().is3xxRedirection()) {
				URI destino = respuesta.getHeaders().getLocation();
				if (destino != null && destino.getHost() != null
						&& destino.getHost().endsWith(".googleusercontent.com")) {
					cuerpo = restClient.get().uri(destino).retrieve().body(String.class);
				}
			}
			if (!"OK".equals(cuerpo == null ? null : cuerpo.trim())) {
				throw new IllegalStateException("El servicio de correo no confirmó el envío.");
			}
		} catch (RestClientException error) {
			cambios.deleteById(usuarioId);
			throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
					"No se pudo enviar el correo de verificación. Inténtalo más tarde.");
		} catch (IllegalStateException error) {
			cambios.deleteById(usuarioId);
			throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
					"No se pudo enviar el correo de verificación. Inténtalo más tarde.");
		}
	}

	public void verificar(String usuarioId, String codigo) {
		CambioPerfilPendiente cambio = cambios.findById(usuarioId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
						"No hay cambios pendientes de verificación."));
		if (!cambio.expiraEn().isAfter(LocalDateTime.now())) {
			cambios.delete(cambio);
			throw new ResponseStatusException(HttpStatus.GONE, "El código venció; solicita uno nuevo.");
		}
		if (cambio.intentos() >= MAX_INTENTOS) {
			cambios.delete(cambio);
			throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,
					"Se agotaron los intentos. Solicita un código nuevo.");
		}
		if (codigo == null || !passwordEncoder.matches(codigo, cambio.codigoHash())) {
			int intentos = cambio.intentos() + 1;
			if (intentos >= MAX_INTENTOS) {
				cambios.delete(cambio);
			} else {
				cambios.save(new CambioPerfilPendiente(cambio.usuarioId(), cambio.codigoHash(),
						cambio.correoNuevo(), cambio.telefonoNuevo(), cambio.contrasenaHashNueva(),
						intentos, cambio.creadoEn(), cambio.expiraEn()));
			}
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código no es correcto.");
		}
		Cuenta cuenta = buscarCuenta(usuarioId);
		if (cambio.correoNuevo() != null) validarCorreoDisponible(cambio.correoNuevo(), usuarioId);
		if (cuenta.usuario() != null) {
			User user = cuenta.usuario();
			if (cambio.correoNuevo() != null) user.setCorreo(cambio.correoNuevo());
			if (cambio.telefonoNuevo() != null) user.setTelefono(cambio.telefonoNuevo());
			if (cambio.contrasenaHashNueva() != null) user.setPasswordHash(cambio.contrasenaHashNueva());
			userRepository.save(user);
		} else if (cuenta.admin() != null) {
			ItAdmin admin = cuenta.admin();
			if (cambio.correoNuevo() != null) admin.setCorreo(cambio.correoNuevo());
			if (cambio.telefonoNuevo() != null) admin.setTelefono(cambio.telefonoNuevo());
			if (cambio.contrasenaHashNueva() != null) admin.setPasswordHash(cambio.contrasenaHashNueva());
			itAdminRepository.save(admin);
		} else {
			Coordinator coordinator = cuenta.coordinator();
			if (cambio.correoNuevo() != null) coordinator.setCorreo(cambio.correoNuevo());
			if (cambio.telefonoNuevo() != null) coordinator.setTelefono(cambio.telefonoNuevo());
			if (cambio.contrasenaHashNueva() != null) coordinator.setPasswordHash(cambio.contrasenaHashNueva());
			coordinatorRepository.save(coordinator);
		}
		cambios.delete(cambio);
	}

	private Cuenta buscarCuenta(String usuarioId) {
		User user = userRepository.findById(usuarioId).orElse(null);
		if (user != null) return new Cuenta(user, null, user.getCorreo());
		ItAdmin admin = itAdminRepository.findById(usuarioId).orElse(null);
		if (admin != null) return new Cuenta(null, admin, admin.getCorreo());
		Coordinator coordinator = coordinatorRepository.findById(usuarioId).orElse(null);
		if (coordinator != null) return new Cuenta(null, null, coordinator, coordinator.getCorreo());
		throw new NotFoundException("No se encontró una cuenta con correo para verificar cambios.");
	}

	private void validarCorreoDisponible(String correo, String usuarioId) {
		boolean ocupado = userRepository.findAll().stream()
				.anyMatch(user -> !usuarioId.equals(user.getId()) && user.getCorreo() != null
						&& correo.equalsIgnoreCase(user.getCorreo().trim()))
				|| itAdminRepository.findAll().stream()
						.anyMatch(admin -> !usuarioId.equals(admin.getId()) && admin.getCorreo() != null
								&& correo.equalsIgnoreCase(admin.getCorreo().trim()))
				|| coordinatorRepository.findAll().stream()
						.anyMatch(coordinator -> !usuarioId.equals(coordinator.getId()) && coordinator.getCorreo() != null
								&& correo.equalsIgnoreCase(coordinator.getCorreo().trim()));
		if (ocupado) throw new ResponseStatusException(HttpStatus.CONFLICT, "Ese correo ya está asociado a otra cuenta.");
	}

	private String limpiar(String valor) {
		return valor == null || valor.isBlank() ? null : valor.trim();
	}

	private record Cuenta(User usuario, ItAdmin admin, Coordinator coordinator, String correo) {
		private Cuenta(User usuario, ItAdmin admin, String correo) {
			this(usuario, admin, null, correo);
		}
	}
}
