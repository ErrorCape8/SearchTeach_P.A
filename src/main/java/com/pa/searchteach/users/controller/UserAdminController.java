package com.pa.searchteach.users.controller;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.it.model.ItAdmin;
import com.pa.searchteach.it.repository.ItAdminRepository;
import com.pa.searchteach.users.dto.UserResponse;
import com.pa.searchteach.users.dto.UserUpdateRequest;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/admin")
public class UserAdminController {

	private final UserRepository userRepository;
	private final ItAdminRepository itAdminRepository;
	private final PasswordEncoder passwordEncoder;

	public UserAdminController(
			UserRepository userRepository,
			ItAdminRepository itAdminRepository,
			PasswordEncoder passwordEncoder) {
		this.userRepository = userRepository;
		this.itAdminRepository = itAdminRepository;
		this.passwordEncoder = passwordEncoder;
	}

	@GetMapping("/users")
	public List<UserResponse> listUsers() {
		return userRepository.findAll().stream()
				.map(u -> new UserResponse(u.getId(), u.getNombre(),
						u.getCorreo(), u.getTelefono(), u.getRol(), u.getEstado()))
				.toList();
	}

	@GetMapping("/users/{id}")
	public ResponseEntity<UserResponse> getUser(@PathVariable String id) {
		User user = userRepository.findById(id)
				.orElseThrow(() -> new NotFoundException("Usuario no encontrado con ID: " + id));
		return ResponseEntity.ok(new UserResponse(user.getId(), user.getNombre(), user.getCorreo(),
				user.getTelefono(), user.getRol(), user.getEstado()));
	}

	@PutMapping("/users/{id}")
	public ResponseEntity<UserResponse> updateUser(@PathVariable String id, @RequestBody UserUpdateRequest request) {
		User user = userRepository.findById(id).orElseGet(() -> {
			User newUser = new User();
			newUser.setId(id);
			return newUser;
		});

		if (request.getNombre() != null) user.setNombre(request.getNombre());
		if (request.getCorreo() != null) user.setCorreo(request.getCorreo());
		if (request.getTelefono() != null) user.setTelefono(request.getTelefono());
		if (request.getRol() != null) user.setRol(request.getRol());
		if (request.getEstado() != null) user.setEstado(request.getEstado());
		if (request.getNuevaContrasena() != null && !request.getNuevaContrasena().trim().isEmpty()) {
			user.setPasswordHash(passwordEncoder.encode(request.getNuevaContrasena().trim()));
		}

		User saved = userRepository.save(user);
		return ResponseEntity.ok(new UserResponse(saved.getId(), saved.getNombre(), saved.getCorreo(),
				saved.getTelefono(), saved.getRol(), saved.getEstado()));
	}

	@PatchMapping("/users/{id}/estado")
	public ResponseEntity<UserResponse> toggleAccess(@PathVariable String id, @RequestParam(required = false) String estado) {
		User user = userRepository.findById(id)
				.orElseThrow(() -> new NotFoundException("Usuario no encontrado con ID: " + id));

		if (estado != null && !estado.isEmpty()) {
			user.setEstado(estado);
		} else {
			String current = user.getEstado();
			user.setEstado("Activo".equalsIgnoreCase(current) ? "Revocado" : "Activo");
		}
		User saved = userRepository.save(user);
		return ResponseEntity.ok(new UserResponse(saved.getId(), saved.getNombre(), saved.getCorreo(),
				saved.getTelefono(), saved.getRol(), saved.getEstado()));
	}

	@GetMapping("/stats")
	public Map<String, Object> getStats() {
		List<User> users = userRepository.findAll();
		return Map.of(
				"cuentasTotal", users.size(),
				"cuentasActivas", users.stream()
						.filter(user -> "Activo".equalsIgnoreCase(user.getEstado()))
						.count(),
				"docentes", users.stream()
						.filter(user -> user.getRol() != null
								&& user.getRol().toLowerCase(Locale.ROOT).contains("docente"))
						.count(),
				"suspendidos", users.stream()
						.filter(user -> "Revocado".equalsIgnoreCase(user.getEstado()))
						.count()
		);
	}

	@GetMapping("/perfil")
	public Map<String, String> getProfile(@AuthenticationPrincipal String adminId) {
		ItAdmin admin = findAdmin(adminId);
		Map<String, String> profile = new LinkedHashMap<>();
		profile.put("nombre", valueOrEmpty(admin.getNombre()));
		profile.put("rol", valueOrEmpty(admin.getRol()));
		profile.put("telefono", valueOrEmpty(admin.getTelefono()));
		profile.put("correo", valueOrEmpty(admin.getCorreo()));
		profile.put("documento", valueOrEmpty(admin.getId()));
		profile.put("programa", valueOrEmpty(admin.getPrograma()));
		return profile;
	}

	@PutMapping("/perfil/telefono")
	public Map<String, String> updatePhone(
			@RequestBody Map<String, String> body,
			@AuthenticationPrincipal String adminId) {
		String phone = body.get("telefono");
		if (phone == null || phone.isBlank()) {
			throw new IllegalArgumentException("El teléfono es obligatorio.");
		}
		ItAdmin admin = findAdmin(adminId);
		admin.setTelefono(phone.trim());
		itAdminRepository.save(admin);
		return getProfile(adminId);
	}

	private ItAdmin findAdmin(String adminId) {
		if (adminId == null || adminId.isBlank()) {
			throw new IllegalArgumentException("No se pudo identificar al administrador.");
		}
		return itAdminRepository.findById(adminId)
				.orElseThrow(() -> new NotFoundException("No se encontró el perfil de TI."));
	}

	private String valueOrEmpty(String value) {
		return value == null ? "" : value;
	}
}
