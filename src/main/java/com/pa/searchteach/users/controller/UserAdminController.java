package com.pa.searchteach.users.controller;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.it.model.ItAdmin;
import com.pa.searchteach.it.repository.ItAdminRepository;
import com.pa.searchteach.users.dto.UserResponse;
import com.pa.searchteach.users.dto.UserUpdateRequest;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
@RequestMapping("/api/admin")
public class UserAdminController {

	private final UserRepository userRepository;
	private final ItAdminRepository itAdminRepository;
	private final PasswordEncoder passwordEncoder;
	private String adminPhone = "605 600 0000";

	public UserAdminController(UserRepository userRepository, ItAdminRepository itAdminRepository, PasswordEncoder passwordEncoder) {
		this.userRepository = userRepository;
		this.itAdminRepository = itAdminRepository;
		this.passwordEncoder = passwordEncoder;
		initDefaultUsersIfEmpty();
	}

	private void initDefaultUsersIfEmpty() {
		try {
			if (userRepository.count() == 0) {
				List<User> defaults = List.of(
						new User("1001", passwordEncoder.encode("12345678"), "Camilo Andres", "candres@comfenalco.edu.co", "3001234567", "Estudiante", "Activo"),
						new User("1002", passwordEncoder.encode("12345678"), "Valentina Ruiz", "vruiz@comfenalco.edu.co", "3002345678", "Estudiante", "Activo"),
						new User("1003", passwordEncoder.encode("12345678"), "Juan Pablo Mora", "jmora@comfenalco.edu.co", "3003456789", "Estudiante", "Activo"),
						new User("1004", passwordEncoder.encode("12345678"), "Laura Martínez", "lmartinez@comfenalco.edu.co", "3004567890", "Docente", "Activo"),
						new User("1005", passwordEncoder.encode("12345678"), "Carlos Chavarriaga", "cchavarriaga@comfenalco.edu.co", "3005678901", "Docente + Estudiante", "Activo"),
						new User("1006", passwordEncoder.encode("12345678"), "Andrés Pérez", "aperez@comfenalco.edu.co", "3006789012", "Docente", "Revocado"),
						new User("1007", passwordEncoder.encode("12345678"), "Sofía Rojas", "srojas@comfenalco.edu.co", "3007890123", "Docente", "Activo"),
						new User("1008", passwordEncoder.encode("12345678"), "Ricardo Vélez", "rvelez@comfenalco.edu.co", "3008901234", "Coordinador", "Activo")
				);
				userRepository.saveAll(defaults);
			}
		} catch (Exception ignored) {
		}
	}

	@GetMapping("/users")
	public List<UserResponse> listUsers() {
		List<User> users = userRepository.findAll();
		if (users.isEmpty()) {
			return List.of(
					new UserResponse("1001", "Camilo Andres", "candres@comfenalco.edu.co", "3001234567", "Estudiante", "Activo"),
					new UserResponse("1002", "Valentina Ruiz", "vruiz@comfenalco.edu.co", "3002345678", "Estudiante", "Activo"),
					new UserResponse("1003", "Juan Pablo Mora", "jmora@comfenalco.edu.co", "3003456789", "Estudiante", "Activo"),
					new UserResponse("1004", "Laura Martínez", "lmartinez@comfenalco.edu.co", "3004567890", "Docente", "Activo"),
					new UserResponse("1005", "Carlos Chavarriaga", "cchavarriaga@comfenalco.edu.co", "3005678901", "Docente + Estudiante", "Activo"),
					new UserResponse("1006", "Andrés Pérez", "aperez@comfenalco.edu.co", "3006789012", "Docente", "Revocado"),
					new UserResponse("1007", "Sofía Rojas", "srojas@comfenalco.edu.co", "3007890123", "Docente", "Activo"),
					new UserResponse("1008", "Ricardo Vélez", "rvelez@comfenalco.edu.co", "3008901234", "Coordinador", "Activo")
			);
		}
		return users.stream()
				.map(u -> new UserResponse(u.getId(), u.getNombre() != null ? u.getNombre() : u.getId(),
						u.getCorreo(), u.getTelefono(),
						u.getRol() != null ? u.getRol() : "Estudiante",
						u.getEstado() != null ? u.getEstado() : "Activo"))
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
		return Map.of(
				"cuentasActivas", 1248,
				"docentes", 86,
				"suspendidos", 2,
				"sincronizacion", "Última sincronización: 02 feb 2026 (+34 cuentas nuevas, 12 accesos revocados)."
		);
	}

	@GetMapping("/perfil")
	public Map<String, String> getProfile() {
		List<ItAdmin> admins = itAdminRepository.findAll();
		if (!admins.isEmpty()) {
			ItAdmin admin = admins.get(0);
			return Map.of(
					"nombre", admin.getNombre(),
					"rol", admin.getRol(),
					"telefono", admin.getTelefono(),
					"correo", admin.getCorreo(),
					"documento", admin.getId() != null ? admin.getId() : "—",
					"programa", admin.getPrograma()
			);
		}
		return Map.of(
				"nombre", "Admin TI",
				"rol", "Administrador",
				"telefono", adminPhone,
				"correo", "ti@comfenalco.edu.co",
				"documento", "—",
				"programa", "Tecnologías de la información"
		);
	}

	@PutMapping("/perfil/telefono")
	public Map<String, String> updatePhone(@RequestBody Map<String, String> body) {
		String phone = body.get("telefono");
		if (phone != null && !phone.trim().isEmpty()) {
			this.adminPhone = phone.trim();
			List<ItAdmin> admins = itAdminRepository.findAll();
			if (!admins.isEmpty()) {
				ItAdmin admin = admins.get(0);
				admin.setTelefono(this.adminPhone);
				itAdminRepository.save(admin);
			}
		}
		return getProfile();
	}
}
