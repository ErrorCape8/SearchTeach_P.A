package com.pa.searchteach.tutorias.controller;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.Duration;
import java.util.Date;
import java.util.Map;
import java.util.List;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

import javax.crypto.SecretKey;

import com.pa.searchteach.tutorias.dto.LiveKitTokenResponse;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.model.MensajeChatTutoria;
import com.pa.searchteach.tutorias.model.AsistenciaEstudiante;
import com.pa.searchteach.tutorias.service.SesionesGrupalesTutoriaService;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@RestController
@RequestMapping("/api/tutorias/grupales")
public class ControladorLiveKit {
	private static final Logger LOG = LoggerFactory.getLogger(ControladorLiveKit.class);

	private final SesionTutoriaRepositorio sesiones;
	private final SesionesGrupalesTutoriaService servicioSesiones;
	private final UserRepository usuarios;
	private final String serverUrl;
	private final String apiKey;
	private final String apiSecret;

	public ControladorLiveKit(
			SesionTutoriaRepositorio sesiones,
			SesionesGrupalesTutoriaService servicioSesiones,
			UserRepository usuarios,
			@Value("${livekit.url:}") String serverUrl,
			@Value("${livekit.api-key:}") String apiKey,
			@Value("${livekit.api-secret:}") String apiSecret) {
		this.sesiones = sesiones;
		this.servicioSesiones = servicioSesiones;
		this.usuarios = usuarios;
		this.serverUrl = serverUrl;
		this.apiKey = apiKey;
		this.apiSecret = apiSecret;
	}

	@GetMapping("/{id}/chat")
	public List<MensajeChatTutoria> historialChat(@PathVariable String id, @AuthenticationPrincipal String usuarioId) {
		SesionTutoria sesion = sesiones.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.docenteId().equals(usuarioId) && !sesion.estudianteIds().contains(usuarioId)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta tutoría.");
		return sesion.historialChat();
	}

	@PostMapping("/{id}/chat")
	public List<MensajeChatTutoria> guardarMensaje(@PathVariable String id, @AuthenticationPrincipal String usuarioId,
			@RequestBody MensajeSolicitud solicitud) {
		return servicioSesiones.registrarMensaje(id, usuarioId, solicitud.texto()).historialChat();
	}

	@PatchMapping("/{id}/asistencia")
	public List<AsistenciaEstudiante> asistencia(@PathVariable String id, @AuthenticationPrincipal String usuarioId,
			@RequestBody AsistenciaSolicitud solicitud) {
		return servicioSesiones.registrarAsistencia(id, usuarioId, solicitud.estudianteId(), solicitud.asistio()).asistencias();
	}

	@PatchMapping("/{id}/finalizar")
	public SesionTutoria finalizar(@PathVariable String id, @AuthenticationPrincipal String usuarioId,
			@RequestBody CierreSolicitud solicitud) {
		SesionTutoria sesion = servicioSesiones.cerrarClase(id, usuarioId, solicitud.motivo());
		return sesion;
	}

	private void cerrarSalaLiveKit(String room) {
		if (serverUrl.isBlank() || apiKey.isBlank() || apiSecret.isBlank()) return;
		try {
			Instant now = Instant.now();
			SecretKey signingKey = Keys.hmacShaKeyFor(apiSecret.getBytes(StandardCharsets.UTF_8));
			String token = Jwts.builder()
					.issuer(apiKey)
					.subject(apiKey)
					.issuedAt(Date.from(now))
					.expiration(Date.from(now.plusSeconds(60)))
					.claim("video", Map.of("room", room, "roomCreate", true, "roomAdmin", true))
					.signWith(signingKey)
					.compact();
			String host = serverUrl.trim().replaceFirst("^wss://", "https://")
					.replaceFirst("^ws://", "http://").replaceAll("/+$", "");
			HttpRequest request = HttpRequest.newBuilder()
					.uri(URI.create(host + "/twirp/livekit.RoomService/DeleteRoom"))
					.timeout(Duration.ofSeconds(8))
					.header("Authorization", "Bearer " + token)
					.header("Content-Type", "application/json")
					.POST(HttpRequest.BodyPublishers.ofString("{\"room\":\"" + room + "\"}"))
					.build();
			HttpResponse<Void> response = HttpClient.newHttpClient().send(request,
					HttpResponse.BodyHandlers.discarding());
			if (response.statusCode() < 200 || response.statusCode() >= 300) {
				LOG.warn("LiveKit no cerró la sala {}. Estado HTTP {}", room, response.statusCode());
			}
		} catch (InterruptedException error) {
			Thread.currentThread().interrupt();
			LOG.warn("Se interrumpió el cierre de la sala LiveKit {}", room, error);
		} catch (Exception error) {
			LOG.warn("No se pudo cerrar la sala LiveKit {}", room, error);
		}
	}

	public record MensajeSolicitud(String texto) {}
	public record AsistenciaSolicitud(String estudianteId, boolean asistio) {}
	public record CierreSolicitud(String motivo) {}
	public record EstudianteSala(String id, String nombre) {}

	@GetMapping("/{id}")
	public SesionTutoria consultarSesion(@PathVariable String id, @AuthenticationPrincipal String usuarioId) {
		SesionTutoria sesion = sesiones.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.docenteId().equals(usuarioId) && !sesion.estudianteIds().contains(usuarioId)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta tutoría.");
		return sesion;
	}

	@GetMapping("/{id}/estudiantes")
	public List<EstudianteSala> estudiantes(@PathVariable String id, @AuthenticationPrincipal String usuarioId) {
		SesionTutoria sesion = sesiones.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.docenteId().equals(usuarioId) && !sesion.estudianteIds().contains(usuarioId)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta tutoría.");
		return sesion.estudianteIds().stream().map(estudianteId -> {
			User estudiante = usuarios.findById(estudianteId).orElse(null);
			String nombre = estudiante == null || estudiante.getNombre() == null || estudiante.getNombre().isBlank()
					? estudianteId : estudiante.getNombre();
			return new EstudianteSala(estudianteId, nombre);
		}).toList();
	}

	@PostMapping("/{id}/livekit-token")
	public LiveKitTokenResponse emitirToken(@PathVariable String id, @AuthenticationPrincipal String usuarioId) {
		if (serverUrl.isBlank() || apiKey.isBlank() || apiSecret.isBlank()) {
			throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
					"La videollamada no está configurada en el servidor.");
		}
		SesionTutoria sesion = sesiones.findById(id)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la sesión."));
		if (!java.util.Set.of(ModalidadTutoria.VIRTUAL, ModalidadTutoria.HIBRIDA).contains(sesion.modalidad())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"LiveKit solo está habilitado para sesiones virtuales o híbridas.");
		}
		if ("FINALIZADA".equals(sesion.estadoClase())) throw new ResponseStatusException(HttpStatus.CONFLICT, "La tutoría ya finalizó.");
		if (!sesion.docenteId().equals(usuarioId) && !sesion.estudianteIds().contains(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta sesión.");
		}
		LocalDateTime horaLocal = LocalDateTime.now(java.time.ZoneId.of("America/Bogota"));
		if (horaLocal.isAfter(sesion.fechaFin().plusHours(1))) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
				"La sesion ya termino y su sala fue cerrada.");
		}

		String room = "searchteach-" + sesion.id();
		return crearTokenSala(usuarioId, room);
	}

	private LiveKitTokenResponse crearTokenSala(String usuarioId, String room) {
		Instant now = Instant.now();
		String participantName = usuarios.findById(usuarioId).map(User::getNombre)
				.filter(nombre -> nombre != null && !nombre.isBlank()).orElse(usuarioId);
		SecretKey signingKey = Keys.hmacShaKeyFor(apiSecret.getBytes(StandardCharsets.UTF_8));
		String token = Jwts.builder()
				.issuer(apiKey)
				.subject(usuarioId)
				.issuedAt(Date.from(now))
				.notBefore(Date.from(now.minusSeconds(5)))
				.expiration(Date.from(now.plusSeconds(3600)))
				.claim("name", participantName)
				.claim("video", Map.of(
						"room", room,
						"roomJoin", true,
						"canPublish", true,
						"canSubscribe", true,
						"canPublishData", true))
				.claim("roomConfig", Map.of("maxParticipants", 6))
				.signWith(signingKey)
				.compact();
		return new LiveKitTokenResponse(serverUrl, token, room);
	}
}
