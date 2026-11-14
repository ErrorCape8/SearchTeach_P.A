package com.pa.searchteach.users.service;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;
import java.util.function.Consumer;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.it.repository.ItAdminRepository;
import com.pa.searchteach.programleaders.repository.RepositorioLiderPrograma;
import com.pa.searchteach.users.dto.PerfilUsuarioResponse;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * Acceso al perfil de cualquier rol (estudiante/docente, coordinador, administrador IT o líder de
 * programa) para consultar el correo y cambiar contraseña o teléfono.
 */
@Service
public class CuentaPerfilService {

	private static final int MAX_BYTES_CONTRASENA = 72;

	private final ItAdminRepository itAdmins;
	private final RepositorioLiderPrograma lideres;
	private final CoordinatorRepository coordinadores;
	private final UserRepository usuarios;
	private final PasswordEncoder passwordEncoder;

	public CuentaPerfilService(
			ItAdminRepository itAdmins,
			RepositorioLiderPrograma lideres,
			CoordinatorRepository coordinadores,
			UserRepository usuarios,
			PasswordEncoder passwordEncoder) {
		this.itAdmins = itAdmins;
		this.lideres = lideres;
		this.coordinadores = coordinadores;
		this.usuarios = usuarios;
		this.passwordEncoder = passwordEncoder;
	}

	/** Perfil de los roles que no son {@code User}; vacío si el id no corresponde a ninguno. */
	public Optional<PerfilUsuarioResponse> perfilAdministrativo(String id) {
		return itAdmins.findById(id)
				.map(admin -> new PerfilUsuarioResponse(admin.getId(), valor(admin.getNombre()),
						valor(admin.getCorreo()), valor(admin.getTelefono()),
						valor(admin.getRol()).isBlank() ? "Administrador" : admin.getRol(),
						"", 0, List.of()))
				.or(() -> lideres.findById(id)
						.map(lider -> new PerfilUsuarioResponse(lider.getId(), "", "", "",
								"Director", "", 0, List.of())))
				.or(() -> coordinadores.findById(id)
						.map(coordinador -> new PerfilUsuarioResponse(coordinador.getId(), "",
								valor(coordinador.getCorreo()), valor(coordinador.getTelefono()),
								"Coordinador", "", 0, List.of())));
	}

	/** Correo registrado en el perfil, que es donde se envían los códigos de seguridad. */
	public String correoDe(String id) {
		String correo = buscar(id).correo();
		if (correo == null || correo.isBlank()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Tu perfil no tiene un correo registrado para enviarte el código.");
		}
		return correo.trim();
	}

	public void validarNuevaContrasena(String nueva, String confirmacion) {
		if (!nueva.equals(confirmacion)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Las contraseñas no coinciden.");
		}
		if (nueva.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES_CONTRASENA) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"La contraseña no puede superar 72 bytes en UTF-8.");
		}
	}

	public void cambiarContrasena(String id, String nueva) {
		buscar(id).guardarContrasena().accept(passwordEncoder.encode(nueva));
	}

	public void cambiarTelefono(String id, String telefono) {
		buscar(id).guardarTelefono().accept(telefono.trim());
	}

	private Cuenta buscar(String id) {
		var itAdmin = itAdmins.findById(id);
		if (itAdmin.isPresent()) {
			var admin = itAdmin.get();
			return new Cuenta(admin.getCorreo(),
					telefono -> { admin.setTelefono(telefono); itAdmins.save(admin); },
					hash -> { admin.setPasswordHash(hash); itAdmins.save(admin); });
		}
		var lider = lideres.findById(id);
		if (lider.isPresent()) {
			var programa = lider.get();
			return new Cuenta(null,
					telefono -> { throw sinTelefonoNiCorreo(); },
					hash -> { programa.setPasswordHash(hash); lideres.save(programa); });
		}
		var coordinador = coordinadores.findById(id);
		if (coordinador.isPresent()) {
			var coordinacion = coordinador.get();
			return new Cuenta(coordinacion.getCorreo(),
					telefono -> { coordinacion.setTelefono(telefono); coordinadores.save(coordinacion); },
					hash -> { coordinacion.setPasswordHash(hash); coordinadores.save(coordinacion); });
		}
		var usuario = usuarios.findById(id)
				.orElseThrow(() -> new NotFoundException("No se encontró el perfil del usuario."));
		return new Cuenta(usuario.getCorreo(),
				telefono -> { usuario.setTelefono(telefono); usuarios.save(usuario); },
				hash -> { usuario.setPasswordHash(hash); usuarios.save(usuario); });
	}

	private ResponseStatusException sinTelefonoNiCorreo() {
		return new ResponseStatusException(HttpStatus.CONFLICT,
				"Este perfil no tiene teléfono ni correo registrados.");
	}

	private String valor(String value) {
		return value == null ? "" : value;
	}

	private record Cuenta(
			String correo,
			Consumer<String> guardarTelefono,
			Consumer<String> guardarContrasena) {
	}
}
