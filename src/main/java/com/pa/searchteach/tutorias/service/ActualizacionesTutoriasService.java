package com.pa.searchteach.tutorias.service;

import java.io.IOException;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;

import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Service
public class ActualizacionesTutoriasService {
	private final CopyOnWriteArrayList<SseEmitter> clientes = new CopyOnWriteArrayList<>();

	public SseEmitter suscribir() {
		SseEmitter emitter = new SseEmitter(0L);
		clientes.add(emitter);
		emitter.onCompletion(() -> clientes.remove(emitter));
		emitter.onTimeout(() -> clientes.remove(emitter));
		emitter.onError(error -> clientes.remove(emitter));
		try {
			emitter.send(SseEmitter.event().name("ready").data("connected"));
		} catch (IOException error) {
			clientes.remove(emitter);
			emitter.completeWithError(error);
		}
		return emitter;
	}

	public void publicar(String tipo, String sesionId) {
		for (SseEmitter emitter : clientes) {
			try {
				emitter.send(SseEmitter.event().name("sesion-cambiada")
						.data(Map.of("tipo", tipo, "sesionId", sesionId), MediaType.APPLICATION_JSON));
			} catch (Exception error) {
				clientes.remove(emitter);
			}
		}
	}
}
