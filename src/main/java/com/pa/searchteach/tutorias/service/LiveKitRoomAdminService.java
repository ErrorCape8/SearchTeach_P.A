package com.pa.searchteach.tutorias.service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Map;

import javax.crypto.SecretKey;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class LiveKitRoomAdminService {
	private static final Logger LOG = LoggerFactory.getLogger(LiveKitRoomAdminService.class);
	private final String serverUrl;
	private final String apiKey;
	private final String apiSecret;
	private final HttpClient httpClient = HttpClient.newHttpClient();

	public LiveKitRoomAdminService(
			@Value("${livekit.url:}") String serverUrl,
			@Value("${livekit.api-key:}") String apiKey,
			@Value("${livekit.api-secret:}") String apiSecret) {
		this.serverUrl = serverUrl;
		this.apiKey = apiKey;
		this.apiSecret = apiSecret;
	}

	public void closeGroupTutoringRoom(String sessionId) {
		String room = "searchteach-" + sessionId;
		if (serverUrl.isBlank() || apiKey.isBlank() || apiSecret.isBlank()) {
			LOG.warn("LiveKit no está configurado; no se pudo cerrar la sala {}", room);
			return;
		}
		try {
			Instant now = Instant.now();
			SecretKey signingKey = Keys.hmacShaKeyFor(apiSecret.getBytes(StandardCharsets.UTF_8));
			String token = Jwts.builder()
					.issuer(apiKey)
					.subject(apiKey)
					.issuedAt(Date.from(now))
					.expiration(Date.from(now.plusSeconds(60)))
					.claim("video", Map.of("room", room, "roomCreate", true))
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
			HttpResponse<Void> response = httpClient.send(request, HttpResponse.BodyHandlers.discarding());
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
}
