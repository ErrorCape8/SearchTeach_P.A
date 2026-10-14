package com.pa.searchteach.users.controller;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.users.dto.CambioContrasenaSolicitud;
import com.pa.searchteach.users.dto.PerfilUsuarioResponse;
import com.pa.searchteach.users.dto.TelefonoUsuarioSolicitud;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

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

	@GetMapping("/api/usuarios/perfil")
	public PerfilUsuarioResponse perfil(@AuthenticationPrincipal String usuarioId) {
		User user = userRepository.findById(usuarioId).orElse(null);
		if (user != null) return respuesta(user);
		Coordinator coordinator = coordinatorRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontro el perfil del usuario."));
		return new PerfilUsuarioResponse(
				coordinator.getId(), "", "", valor(coordinator.getTelefono()), "Coordinador", "");
	}

	@PutMapping("/api/usuarios/perfil/telefono")
	public PerfilUsuarioResponse actualizarTelefono(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody TelefonoUsuarioSolicitud solicitud) {
		User user = userRepository.findById(usuarioId).orElse(null);
		if (user != null) {
			user.setTelefono(solicitud.telefono().trim());
			userRepository.save(user);
			return respuesta(user);
		}
		Coordinator coordinator = coordinatorRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontro el perfil del usuario."));
		coordinator.setTelefono(solicitud.telefono().trim());
		coordinatorRepository.save(coordinator);
		return new PerfilUsuarioResponse(
				coordinator.getId(), "", "", valor(coordinator.getTelefono()), "Coordinador", "");
	}

	@PutMapping("/api/usuarios/perfil/contrasena")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void actualizarContrasena(
			@AuthenticationPrincipal String usuarioId,
			@Valid @RequestBody CambioContrasenaSolicitud solicitud) {
		User user = userRepository.findById(usuarioId).orElse(null);
		if (user != null) {
			actualizarPassword(user.getPasswordHash(), solicitud);
			user.setPasswordHash(passwordEncoder.encode(solicitud.nuevaContrasena()));
			userRepository.save(user);
			return;
		}
		Coordinator coordinator = coordinatorRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontro el perfil del usuario."));
		actualizarPassword(coordinator.getPasswordHash(), solicitud);
		coordinator.setPasswordHash(passwordEncoder.encode(solicitud.nuevaContrasena()));
		coordinatorRepository.save(coordinator);
	}

	private void actualizarPassword(String hash, CambioContrasenaSolicitud solicitud) {
		if (hash == null || !passwordEncoder.matches(solicitud.contrasenaActual(), hash)) {
			throw new IllegalArgumentException("La contrasena actual no es correcta.");
		}
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
