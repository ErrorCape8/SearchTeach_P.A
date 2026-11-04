package com.pa.searchteach.tutorias.controller;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Date;
import java.util.Map;
import java.util.Set;

import javax.crypto.SecretKey;

import com.pa.searchteach.tutorias.dto.LiveKitTokenResponse;
import com.pa.searchteach.tutorias.model.EstadoTutoria;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.Tutoria;
import com.pa.searchteach.tutorias.service.ServicioTutorias;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/tutorias")
public class ControladorLiveKitTutoriaIndividual {

	private final ServicioTutorias servicioTutorias;
	private final UserRepository usuarios;
	private final String serverUrl;
	private final String apiKey;
	private final String apiSecret;

	public ControladorLiveKitTutoriaIndividual(
			ServicioTutorias servicioTutorias,
			UserRepository usuarios,
			@Value("${livekit.url:}") String serverUrl,
			@Value("${livekit.api-key:}") String apiKey,
			@Value("${livekit.api-secret:}") String apiSecret) {
		this.servicioTutorias = servicioTutorias;
		this.usuarios = usuarios;
		this.serverUrl = serverUrl;
		this.apiKey = apiKey;
		this.apiSecret = apiSecret;
	}

	@PostMapping("/{id}/livekit-token")
	public LiveKitTokenResponse emitirToken(@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		if (serverUrl.isBlank() || apiKey.isBlank() || apiSecret.isBlank()) {
			throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
					"La videollamada no está configurada en el servidor.");
		}
		Tutoria tutoria = servicioTutorias.buscar(id, usuarioId);
		if (!Set.of(ModalidadTutoria.VIRTUAL, ModalidadTutoria.HIBRIDA).contains(tutoria.getModalidad())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"LiveKit solo está habilitado para tutorías virtuales o híbridas.");
		}
		if (usuarioId.equals(tutoria.getDocenteId())) {
			if (tutoria.getEstado() == EstadoTutoria.PROGRAMADA) {
				tutoria = servicioTutorias.iniciar(id, usuarioId);
			} else if (tutoria.getEstado() != EstadoTutoria.EN_CURSO) {
				throw new ResponseStatusException(HttpStatus.CONFLICT,
						"La tutoría no está disponible para iniciar.");
			}
		} else if (tutoria.getEstado() != EstadoTutoria.EN_CURSO) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El docente debe iniciar la tutoría antes de que puedas unirte.");
		}
		LocalDateTime horaLocal = LocalDateTime.now(java.time.ZoneId.of("America/Bogota"));
		if (tutoria.getFechaFin() != null && horaLocal.isAfter(tutoria.getFechaFin().plusHours(1))) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La tutoría ya terminó y su sala no está disponible.");
		}
		return crearTokenSala(usuarioId, "searchteach-individual-" + tutoria.getId());
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
				.claim("roomConfig", Map.of("maxParticipants", 2))
				.signWith(signingKey)
				.compact();
		return new LiveKitTokenResponse(serverUrl, token, room);
	}
}
