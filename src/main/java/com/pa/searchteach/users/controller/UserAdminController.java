package com.pa.searchteach.users.controller;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.it.model.ItAdmin;
import com.pa.searchteach.it.repository.ItAdminRepository;
import com.pa.searchteach.users.dto.UserResponse;
import com.pa.searchteach.users.dto.UserCreateRequest;
import com.pa.searchteach.users.dto.UserUpdateRequest;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
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
					 u.getCorreo(), u.getTelefono(), u.getRol(), u.getEstado(), u.getCarrera(), u.getTitulosAcademicos()))
				.toList();
	}

	@PostMapping("/users/import")
	public ResponseEntity<?> importUsers(@RequestBody Map<String, List<UserCreateRequest>> payload) {
		List<UserCreateRequest> rows = payload == null ? null : payload.get("usuarios");
		if (rows == null || rows.isEmpty()) {
			return invalidImport();
		}

		Set<String> ids = new HashSet<>();
		Set<String> emails = new HashSet<>();
		for (UserCreateRequest row : rows) {
			if (row == null || row.id() == null || !row.id().matches("[0-9]{6,10}")
					|| blank(row.nombre()) || blank(row.correo()) || blank(row.telefono())
					|| blank(row.rol()) || blank(row.estado())
					|| (row.rol().toLowerCase(Locale.ROOT).contains("estudiante") && blank(row.carrera()))
					|| !row.correo().matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")
					|| (!blank(row.carrera()) && !CatalogoTecnologias.contiene(row.carrera()))
					|| !(row.estado().equalsIgnoreCase("Activo") || row.estado().equalsIgnoreCase("Revocado"))
					|| !ids.add(row.id()) || !emails.add(row.correo().trim().toLowerCase(Locale.ROOT))) {
				return invalidImport();
			}
		}

		List<User> existing = userRepository.findAll();
		Set<String> existingIds = new HashSet<>();
		Set<String> existingEmails = new HashSet<>();
		for (User user : existing) {
			existingIds.add(user.getId());
			if (!blank(user.getCorreo())) {
				existingEmails.add(user.getCorreo().trim().toLowerCase(Locale.ROOT));
			}
		}
		if (ids.stream().anyMatch(existingIds::contains) || emails.stream().anyMatch(existingEmails::contains)) {
			return invalidImport();
		}

		List<User> users = rows.stream().map(row -> new User(
				row.id().trim(), null, row.nombre().trim(), row.correo().trim().toLowerCase(Locale.ROOT),
				row.telefono().trim(), row.rol().trim(),
				row.estado().equalsIgnoreCase("activo") ? "Activo" : "Revocado",
				row.carrera() == null ? "" : row.carrera().trim()))
				.toList();
		List<UserResponse> created = userRepository.saveAll(users).stream()
				.map(u -> new UserResponse(u.getId(), u.getNombre(), u.getCorreo(),
					u.getTelefono(), u.getRol(), u.getEstado(), u.getCarrera(), u.getTitulosAcademicos()))
				.toList();
		return ResponseEntity.status(HttpStatus.CREATED).body(created);
	}

	private boolean blank(String value) {
		return value == null || value.isBlank();
	}

	private ResponseEntity<Map<String, String>> invalidImport() {
		return ResponseEntity.badRequest().body(Map.of(
				"message", "no todos los usuairos cumplen con los parametros"));
	}

	@GetMapping("/users/{id}")
	public ResponseEntity<UserResponse> getUser(@PathVariable String id) {
		User user = userRepository.findById(id)
				.orElseThrow(() -> new NotFoundException("Usuario no encontrado con ID: " + id));
		return ResponseEntity.ok(new UserResponse(user.getId(), user.getNombre(), user.getCorreo(),
				user.getTelefono(), user.getRol(), user.getEstado(), user.getCarrera(), user.getTitulosAcademicos()));
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
		if (request.getTitulosAcademicos() != null && user.getRol() != null
				&& user.getRol().toLowerCase(Locale.ROOT).contains("docente")) {
			LinkedHashSet<String> titles = new LinkedHashSet<>();
			request.getTitulosAcademicos().stream()
					.filter(Objects::nonNull)
					.map(String::trim)
					.filter(title -> !title.isEmpty())
					.forEach(titles::add);
			user.setTitulosAcademicos(new ArrayList<>(titles));
		}
		if (request.getCarrera() != null) {
			if (!blank(request.getCarrera()) && !CatalogoTecnologias.contiene(request.getCarrera())) {
				throw new IllegalArgumentException("Selecciona una tecnología del catálogo institucional.");
			}
			user.setCarrera(request.getCarrera().trim());
		}
		if (user.getRol() != null && user.getRol().toLowerCase(Locale.ROOT).contains("estudiante")
				&& blank(user.getCarrera())) {
			throw new IllegalArgumentException("Asigna una tecnología al estudiante antes de guardar.");
		}
		if (request.getNuevaContrasena() != null && !request.getNuevaContrasena().trim().isEmpty()) {
			user.setPasswordHash(passwordEncoder.encode(request.getNuevaContrasena().trim()));
		}

		User saved = userRepository.save(user);
		return ResponseEntity.ok(new UserResponse(saved.getId(), saved.getNombre(), saved.getCorreo(),
				saved.getTelefono(), saved.getRol(), saved.getEstado(), saved.getCarrera(), saved.getTitulosAcademicos()));
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
				saved.getTelefono(), saved.getRol(), saved.getEstado(), saved.getCarrera(), saved.getTitulosAcademicos()));
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
