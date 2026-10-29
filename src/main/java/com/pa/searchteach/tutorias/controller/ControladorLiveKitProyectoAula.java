package com.pa.searchteach.tutorias.controller;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Date;
import java.util.Map;

import javax.crypto.SecretKey;

import com.pa.searchteach.tutorias.dto.LiveKitTokenResponse;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.service.TutoriasColectivasService;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
public class ControladorLiveKitProyectoAula {
	private final TutoriasColectivasService proyectosAula;
	private final UserRepository usuarios;
	private final String serverUrl;
	private final String apiKey;
	private final String apiSecret;

	public ControladorLiveKitProyectoAula(
			TutoriasColectivasService proyectosAula,
			UserRepository usuarios,
			@Value("${livekit.url:}") String serverUrl,
			@Value("${livekit.api-key:}") String apiKey,
			@Value("${livekit.api-secret:}") String apiSecret) {
		this.proyectosAula = proyectosAula;
		this.usuarios = usuarios;
		this.serverUrl = serverUrl;
		this.apiKey = apiKey;
		this.apiSecret = apiSecret;
	}

	@PostMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/livekit-token")
	public LiveKitTokenResponse emitirToken(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@AuthenticationPrincipal String usuarioId) {
		if (serverUrl.isBlank() || apiKey.isBlank() || apiSecret.isBlank()) {
			throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
					"La videollamada no está configurada en el servidor.");
		}
		ProyectoAula proyecto = proyectosAula.obtenerProyectoEnChat(tutoriaId, proyectoId, sesionId, usuarioId);
		if (proyecto.fechaReunion() == null || !sesionId.equals(proyecto.reunionSesionId())
				|| proyecto.reunionMensajePublicadoEn() == null) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "La reunión todavía no ha comenzado.");
		}
		if ("FINALIZADO".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "El proyecto ya fue finalizado.");
		}
		LocalDateTime ahora = LocalDateTime.now();
		if (ahora.isBefore(proyecto.fechaReunion().minusMinutes(15))
				|| ahora.isAfter(proyecto.fechaReunion().plusHours(2))) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La sala estará disponible 15 minutos antes de iniciar y hasta dos horas después.");
		}
		String room = "searchteach-pa-" + proyecto.proyectoId();
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
				.claim("video", Map.of("room", room, "roomJoin", true, "canPublish", true,
						"canSubscribe", true, "canPublishData", true))
				.claim("roomConfig", Map.of("maxParticipants", 6))
				.signWith(signingKey)
				.compact();
		return new LiveKitTokenResponse(serverUrl, token, room);
	}
}
