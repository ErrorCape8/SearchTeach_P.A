package com.pa.searchteach.users.controller;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.users.dto.PerfilUsuarioResponse;
import com.pa.searchteach.users.dto.ActualizarSemestreSolicitud;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class UserProfileController {

	private final UserRepository userRepository;
	private final CoordinatorRepository coordinatorRepository;

	public UserProfileController(
			UserRepository userRepository,
			CoordinatorRepository coordinatorRepository) {
		this.userRepository = userRepository;
		this.coordinatorRepository = coordinatorRepository;
	}

	@GetMapping("/api/usuarios/perfil")
	public PerfilUsuarioResponse perfil(@AuthenticationPrincipal String usuarioId) {
		User user = userRepository.findById(usuarioId).orElse(null);
		if (user != null) return respuesta(user);
		Coordinator coordinator = coordinatorRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontro el perfil del usuario."));
		return new PerfilUsuarioResponse(
				coordinator.getId(), "", valor(coordinator.getCorreo()), valor(coordinator.getTelefono()), "Coordinador", "", 0);
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
				valor(user.getTelefono()), valor(user.getRol()), valor(user.getCarrera()), user.getSemestre());
	}

	private String valor(String value) {
		return value == null ? "" : value;
	}
}
