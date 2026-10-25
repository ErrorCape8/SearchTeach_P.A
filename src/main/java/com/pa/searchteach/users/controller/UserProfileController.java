package com.pa.searchteach.users.controller;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.users.dto.PerfilUsuarioResponse;
import com.pa.searchteach.users.dto.SolicitudCambioPerfil;
import com.pa.searchteach.users.dto.VerificarCambioPerfilSolicitud;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import com.pa.searchteach.users.service.VerificacionCambioPerfilService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class UserProfileController {

	private final UserRepository userRepository;
	private final CoordinatorRepository coordinatorRepository;
	private final VerificacionCambioPerfilService verificacionCambioPerfil;

	public UserProfileController(
			UserRepository userRepository,
			CoordinatorRepository coordinatorRepository,
			VerificacionCambioPerfilService verificacionCambioPerfil) {
		this.userRepository = userRepository;
		this.coordinatorRepository = coordinatorRepository;
		this.verificacionCambioPerfil = verificacionCambioPerfil;
	}

	@GetMapping("/api/usuarios/perfil")
	public PerfilUsuarioResponse perfil(@AuthenticationPrincipal String usuarioId) {
		User user = userRepository.findById(usuarioId).orElse(null);
		if (user != null) return respuesta(user);
		Coordinator coordinator = coordinatorRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontro el perfil del usuario."));
		return new PerfilUsuarioResponse(
				coordinator.getId(), "", valor(coordinator.getCorreo()), valor(coordinator.getTelefono()), "Coordinador", "");
	}

	@PostMapping("/api/usuarios/perfil/cambios/solicitar")
	@ResponseStatus(org.springframework.http.HttpStatus.ACCEPTED)
	public void solicitarCambioPerfil(
			@AuthenticationPrincipal String usuarioId,
			@RequestBody SolicitudCambioPerfil solicitud) {
		verificacionCambioPerfil.solicitar(usuarioId, solicitud);
	}

	@PostMapping("/api/usuarios/perfil/cambios/verificar")
	@ResponseStatus(org.springframework.http.HttpStatus.NO_CONTENT)
	public void verificarCambioPerfil(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody VerificarCambioPerfilSolicitud solicitud) {
		verificacionCambioPerfil.verificar(usuarioId, solicitud.codigo());
	}

	private PerfilUsuarioResponse respuesta(User user) {
		return new PerfilUsuarioResponse(
				user.getId(), valor(user.getNombre()), valor(user.getCorreo()),
				valor(user.getTelefono()), valor(user.getRol()), valor(user.getCarrera()));
	}

	private String valor(String value) {
		return value == null ? "" : value;
	}
}
