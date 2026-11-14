package com.pa.searchteach.users.controller;

import java.util.Locale;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.users.dto.ActualizarSemestreSolicitud;
import com.pa.searchteach.users.dto.CambioContrasenaSolicitud;
import com.pa.searchteach.users.dto.CodigoEnviadoResponse;
import com.pa.searchteach.users.dto.CodigoVerificacionSolicitud;
import com.pa.searchteach.users.dto.PerfilUsuarioResponse;
import com.pa.searchteach.users.dto.TelefonoUsuarioSolicitud;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import com.pa.searchteach.users.service.CuentaPerfilService;
import com.pa.searchteach.users.service.PerfilVerificacionService;
import com.pa.searchteach.users.service.PerfilVerificacionService.Proposito;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * Perfil del usuario autenticado.
 *
 * <p>Cambiar la contraseña, y agregar o cambiar el teléfono, exige tres pasos:
 * <ol>
 *   <li>{@code POST .../codigo}: se envía un código de 6 dígitos al correo del perfil.</li>
 *   <li>{@code POST .../verificar}: se confirma el código.</li>
 *   <li>{@code PATCH ...}: se aplica el cambio (la contraseña con su confirmación, o el teléfono).</li>
 * </ol>
 */
@RestController
public class UserProfileController {

	private final UserRepository userRepository;
	private final CuentaPerfilService cuentas;
	private final PerfilVerificacionService verificacion;

	public UserProfileController(
			UserRepository userRepository,
			CuentaPerfilService cuentas,
			PerfilVerificacionService verificacion) {
		this.userRepository = userRepository;
		this.cuentas = cuentas;
		this.verificacion = verificacion;
	}

	@GetMapping("/api/usuarios/perfil")
	public PerfilUsuarioResponse perfil(@AuthenticationPrincipal String usuarioId) {
		return userRepository.findById(usuarioId)
				.map(this::respuesta)
				.or(() -> cuentas.perfilAdministrativo(usuarioId))
				.orElseThrow(() -> new NotFoundException("No se encontró el perfil del usuario."));
	}

	@PostMapping("/api/usuarios/perfil/contrasena/codigo")
	public CodigoEnviadoResponse enviarCodigoContrasena(@AuthenticationPrincipal String usuarioId) {
		return new CodigoEnviadoResponse(verificacion.enviarCodigo(usuarioId, Proposito.CONTRASENA));
	}

	@PostMapping("/api/usuarios/perfil/contrasena/verificar")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void verificarCodigoContrasena(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody CodigoVerificacionSolicitud solicitud) {
		verificacion.verificarCodigo(usuarioId, Proposito.CONTRASENA, solicitud.code());
	}

	@PatchMapping("/api/usuarios/perfil/contrasena")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void actualizarContrasena(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody CambioContrasenaSolicitud solicitud) {
		cuentas.validarNuevaContrasena(solicitud.nuevaContrasena(), solicitud.confirmarContrasena());
		verificacion.exigirVerificado(usuarioId, Proposito.CONTRASENA);
		cuentas.cambiarContrasena(usuarioId, solicitud.nuevaContrasena());
		verificacion.consumir(usuarioId, Proposito.CONTRASENA);
	}

	@PostMapping("/api/usuarios/perfil/telefono/codigo")
	public CodigoEnviadoResponse enviarCodigoTelefono(@AuthenticationPrincipal String usuarioId) {
		return new CodigoEnviadoResponse(verificacion.enviarCodigo(usuarioId, Proposito.TELEFONO));
	}

	@PostMapping("/api/usuarios/perfil/telefono/verificar")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void verificarCodigoTelefono(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody CodigoVerificacionSolicitud solicitud) {
		verificacion.verificarCodigo(usuarioId, Proposito.TELEFONO, solicitud.code());
	}

	@PatchMapping("/api/usuarios/perfil/telefono")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void actualizarTelefono(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody TelefonoUsuarioSolicitud solicitud) {
		verificacion.exigirVerificado(usuarioId, Proposito.TELEFONO);
		cuentas.cambiarTelefono(usuarioId, solicitud.telefono());
		verificacion.consumir(usuarioId, Proposito.TELEFONO);
	}

	@PatchMapping("/api/usuarios/perfil/semestre")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void actualizarSemestre(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody ActualizarSemestreSolicitud solicitud) {
		User user = userRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontró el perfil del estudiante."));
		if (user.getRol() == null || !user.getRol().toLowerCase(Locale.ROOT).contains("estudiante")) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Esta opción es solo para estudiantes.");
		}
		if (user.getSemestre() >= 1 && user.getSemestre() <= 6) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "Tu semestre ya está registrado.");
		}
		user.setSemestre(solicitud.semestre());
		userRepository.save(user);
	}

	private PerfilUsuarioResponse respuesta(User user) {
		return new PerfilUsuarioResponse(
				user.getId(), valor(user.getNombre()), valor(user.getCorreo()),
				valor(user.getTelefono()), valor(user.getRol()), valor(user.getCarrera()), user.getSemestre(),
				user.getMateriasPrincipales());
	}

	private String valor(String value) {
		return value == null ? "" : value;
	}
}
