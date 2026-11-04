package com.pa.searchteach.users.controller;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.users.dto.PerfilUsuarioResponse;
import com.pa.searchteach.users.dto.ActualizarSemestreSolicitud;
import com.pa.searchteach.users.dto.TelefonoUsuarioSolicitud;
import com.pa.searchteach.users.dto.CambioContrasenaSolicitud;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.security.crypto.password.PasswordEncoder;

@RestController
public class UserProfileController {

	private final UserRepository userRepository;
	private final CoordinatorRepository coordinatorRepository;
	private final PasswordEncoder passwordEncoder;

	public UserProfileController(
			UserRepository userRepository,
			CoordinatorRepository coordinatorRepository,
			PasswordEncoder passwordEncoder) {
		this.userRepository = userRepository;
		this.coordinatorRepository = coordinatorRepository;
		this.passwordEncoder = passwordEncoder;
	}

	@PatchMapping("/api/usuarios/perfil/telefono")
	@ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
	public void actualizarTelefono(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody TelefonoUsuarioSolicitud solicitud) {
		User user = userRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontró el perfil del usuario."));
		user.setTelefono(solicitud.telefono().trim());
		userRepository.save(user);
	}

	@PatchMapping("/api/usuarios/perfil/contrasena")
	@ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
	public void actualizarContrasena(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody CambioContrasenaSolicitud solicitud) {
		User user = userRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontró el perfil del usuario."));
		if (!passwordEncoder.matches(solicitud.contrasenaActual(), user.getPasswordHash())) {
			throw new org.springframework.web.server.ResponseStatusException(
					org.springframework.http.HttpStatus.CONFLICT, "La contraseña actual no es correcta.");
		}
		user.setPasswordHash(passwordEncoder.encode(solicitud.nuevaContrasena()));
		userRepository.save(user);
	}

	@GetMapping("/api/usuarios/perfil")
	public PerfilUsuarioResponse perfil(@AuthenticationPrincipal String usuarioId) {
		User user = userRepository.findById(usuarioId).orElse(null);
		if (user != null) return respuesta(user);
		Coordinator coordinator = coordinatorRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontro el perfil del usuario."));
		return new PerfilUsuarioResponse(
				coordinator.getId(), "", valor(coordinator.getCorreo()), valor(coordinator.getTelefono()), "Coordinador", "", 0,
				java.util.List.of());
	}

	@PatchMapping("/api/usuarios/perfil/semestre")
	@ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
	public void actualizarSemestre(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody ActualizarSemestreSolicitud solicitud) {
		User user = userRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontrÃ³ el perfil del estudiante."));
		if (user.getRol() == null || !user.getRol().toLowerCase(java.util.Locale.ROOT).contains("estudiante")) {
			throw new org.springframework.web.server.ResponseStatusException(
					org.springframework.http.HttpStatus.FORBIDDEN, "Esta opciÃ³n es solo para estudiantes.");
		}
		if (user.getSemestre() >= 1 && user.getSemestre() <= 6) {
			throw new org.springframework.web.server.ResponseStatusException(
					org.springframework.http.HttpStatus.CONFLICT, "Tu semestre ya estÃ¡ registrado.");
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
