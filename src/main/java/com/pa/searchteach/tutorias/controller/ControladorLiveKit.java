package com.pa.searchteach.tutorias.controller;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Date;
import java.util.Map;
import java.util.List;

import javax.crypto.SecretKey;

import com.pa.searchteach.tutorias.dto.LiveKitTokenResponse;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.model.MensajeChatTutoria;
import com.pa.searchteach.tutorias.model.AsistenciaEstudiante;
import com.pa.searchteach.tutorias.service.SesionesGrupalesTutoriaService;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
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

@RestController
@RequestMapping("/api/tutorias/grupales")
public class ControladorLiveKit {

	private final SesionTutoriaRepositorio sesiones;
	private final SesionesGrupalesTutoriaService servicioSesiones;
	private final String serverUrl;
	private final String apiKey;
	private final String apiSecret;

	public ControladorLiveKit(
			SesionTutoriaRepositorio sesiones,
			SesionesGrupalesTutoriaService servicioSesiones,
			@Value("${livekit.url:}") String serverUrl,
			@Value("${livekit.api-key:}") String apiKey,
			@Value("${livekit.api-secret:}") String apiSecret) {
		this.sesiones = sesiones;
		this.servicioSesiones = servicioSesiones;
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
		return servicioSesiones.cerrarClase(id, usuarioId, solicitud.motivo());
	}

	public record MensajeSolicitud(String texto) {}
	public record AsistenciaSolicitud(String estudianteId, boolean asistio) {}
	public record CierreSolicitud(String motivo) {}

	@GetMapping("/{id}")
	public SesionTutoria consultarSesion(@PathVariable String id, @AuthenticationPrincipal String usuarioId) {
		SesionTutoria sesion = sesiones.findById(id).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.docenteId().equals(usuarioId) && !sesion.estudianteIds().contains(usuarioId)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta tutoría.");
		return sesion;
	}

	@PostMapping("/{id}/livekit-token")
	public LiveKitTokenResponse emitirToken(@PathVariable String id, @AuthenticationPrincipal String usuarioId) {
		if (serverUrl.isBlank() || apiKey.isBlank() || apiSecret.isBlank()) {
			throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
					"La videollamada no está configurada en el servidor.");
		}
		SesionTutoria sesion = sesiones.findById(id)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la sesión."));
		if (sesion.modalidad() != null && !java.util.Set.of(
				ModalidadTutoria.VIRTUAL, ModalidadTutoria.HIBRIDA, ModalidadTutoria.PRESENCIAL).contains(sesion.modalidad())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"LiveKit solo está habilitado para sesiones virtuales o híbridas.");
		}
		if ("FINALIZADA".equals(sesion.estadoClase())) throw new ResponseStatusException(HttpStatus.CONFLICT, "La tutoría ya finalizó.");
		if (!sesion.docenteId().equals(usuarioId) && !sesion.estudianteIds().contains(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta sesión.");
		}
		Instant now = Instant.now();
		LocalDateTime horaLocal = LocalDateTime.now();
		if (horaLocal.isBefore(sesion.fechaInicio().minusMinutes(15))
				|| horaLocal.isAfter(sesion.fechaFin().plusHours(1))) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La sala estará disponible 15 minutos antes de iniciar y hasta una hora después de finalizar.");
		}

		String room = "searchteach-" + sesion.id();
		SecretKey signingKey = Keys.hmacShaKeyFor(apiSecret.getBytes(StandardCharsets.UTF_8));
		String token = Jwts.builder()
				.issuer(apiKey)
				.subject(usuarioId)
				.issuedAt(Date.from(now))
				.notBefore(Date.from(now.minusSeconds(5)))
				.expiration(Date.from(now.plusSeconds(3600)))
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
