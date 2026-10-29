package com.pa.searchteach.tutorias.service;

import java.io.IOException;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pa.searchteach.tutorias.dto.MensajeProyectoAulaVista;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Service
public class ProyectoAulaChatRedisService implements MessageListener {
	private static final Logger LOGGER = Logger.getLogger(ProyectoAulaChatRedisService.class.getName());
	public static final String CHANNEL = "searchteach:proyecto-aula:chat";
	private final StringRedisTemplate redis;
	private final ObjectMapper mapper;
	private final Map<String, CopyOnWriteArrayList<Client>> clients = new ConcurrentHashMap<>();

	public ProyectoAulaChatRedisService(StringRedisTemplate redis, ObjectMapper mapper) {
		this.redis = redis;
		this.mapper = mapper;
	}

	public SseEmitter subscribe(String tutoringId, String projectId, String sessionId, String userId) {
		String room = roomKey(tutoringId, projectId, sessionId);
		SseEmitter emitter = new SseEmitter(0L);
		Client client = new Client(userId, emitter);
		clients.computeIfAbsent(room, ignored -> new CopyOnWriteArrayList<>()).add(client);
		emitter.onCompletion(() -> remove(room, client));
		emitter.onTimeout(() -> remove(room, client));
		emitter.onError(error -> remove(room, client));
		try {
			emitter.send(SseEmitter.event().name("ready").data("connected"));
		} catch (IOException error) {
			remove(room, client);
			emitter.completeWithError(error);
		}
		return emitter;
	}

	public void publish(String tutoringId, String projectId, String sessionId,
			MensajeProyectoAulaVista message) {
		try {
			redis.convertAndSend(CHANNEL, mapper.writeValueAsString(
					Map.of("room", roomKey(tutoringId, projectId, sessionId), "message", message)));
		} catch (Exception error) {
			LOGGER.log(Level.WARNING, "No se pudo publicar el mensaje del chat en Redis; se conserva en MongoDB.", error);
		}
	}

	@Override
	public void onMessage(Message message, byte[] pattern) {
		try {
			Map<String, Object> event = mapper.readValue(message.getBody(),
					new TypeReference<>() {});
			String room = (String) event.get("room");
			Object body = event.get("message");
			if (room == null || body == null) return;
			Map<String, Object> payload = mapper.convertValue(body, new TypeReference<>() {});
			String senderId = String.valueOf(payload.get("emisorId"));
			for (Client client : clients.getOrDefault(room, new CopyOnWriteArrayList<>())) {
				try {
					Map<String, Object> personalized = new java.util.HashMap<>(payload);
					personalized.put("propio", senderId.equals(client.userId()));
					client.emitter().send(SseEmitter.event().name("message")
							.data(mapper.writeValueAsString(personalized), MediaType.APPLICATION_JSON));
				} catch (Exception disconnected) {
					remove(room, client);
				}
			}
		} catch (Exception ignored) {
			// A disconnected browser must not stop delivery to other chat clients.
		}
	}

	private void remove(String room, Client client) {
		CopyOnWriteArrayList<Client> roomClients = clients.get(room);
		if (roomClients == null) return;
		roomClients.remove(client);
		if (roomClients.isEmpty()) clients.remove(room, roomClients);
	}

	private String roomKey(String tutoringId, String projectId, String sessionId) {
		return tutoringId + ":" + projectId + ":" + sessionId;
	}

	private record Client(String userId, SseEmitter emitter) {}
}
