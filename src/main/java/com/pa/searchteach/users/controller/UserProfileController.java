package com.pa.searchteach.users.controller;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.users.dto.PerfilUsuarioResponse;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class UserProfileController {

	private final UserRepository userRepository;

	public UserProfileController(UserRepository userRepository) {
		this.userRepository = userRepository;
	}

	@GetMapping("/api/usuarios/perfil")
	public PerfilUsuarioResponse perfil(@AuthenticationPrincipal String usuarioId) {
		User user = userRepository.findById(usuarioId)
				.orElseThrow(() -> new NotFoundException("No se encontró el perfil del usuario."));
		return new PerfilUsuarioResponse(
				user.getId(),
				valor(user.getNombre()),
				valor(user.getCorreo()),
				valor(user.getTelefono()),
				valor(user.getRol()));
	}

	private String valor(String value) {
		return value == null ? "" : value;
	}
}
