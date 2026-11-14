package com.pa.searchteach.tutorias.controller.colectivas;

import java.util.List;
import java.nio.charset.StandardCharsets;

import com.pa.searchteach.tutorias.dto.colectivas.MensajeProyectoAulaVista;
import com.pa.searchteach.tutorias.model.MensajeProyectoAula;
import com.pa.searchteach.tutorias.service.colectivas.ProyectoAulaChatRedisService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ContentDisposition;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;
import com.pa.searchteach.tutorias.service.colectivas.ReunionesProyectoAulaService;
import com.pa.searchteach.tutorias.service.colectivas.ChatProyectoAulaService;

/** Proyectos de aula: chat de cada reporte y estado de la reunión. */
@RestController
public class ControladorChatProyectoAula {

	private final ReunionesProyectoAulaService reuniones;
	private final ChatProyectoAulaService chat;
	private final ProyectoAulaChatRedisService chatRedis;

	public ControladorChatProyectoAula(
			ReunionesProyectoAulaService reuniones,
			ChatProyectoAulaService chat,
			ProyectoAulaChatRedisService chatRedis) {
		this.reuniones = reuniones;
		this.chat = chat;
		this.chatRedis = chatRedis;
	}

	@GetMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/mensajes")
	public List<MensajeProyectoAulaVista> listarMensajesDelReporte(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @AuthenticationPrincipal String usuarioId) {
		return chat.listarMensajesProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
	}

	@GetMapping(value = "/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/mensajes/stream",
			produces = MediaType.TEXT_EVENT_STREAM_VALUE)
	public SseEmitter escucharMensajesDelReporte(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @AuthenticationPrincipal String usuarioId) {
		chat.obtenerProyectoEnChat(tutoriaId, proyectoId, sesionId, usuarioId);
		return chatRedis.subscribe(tutoriaId, proyectoId, sesionId, usuarioId);
	}

	@GetMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/estado")
	public com.pa.searchteach.tutorias.model.ProyectoAula consultarEstadoDelProyectoEnChat(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @AuthenticationPrincipal String usuarioId) {
		return chat.obtenerProyectoEnChat(tutoriaId, proyectoId, sesionId, usuarioId);
	}

	@PostMapping(value = "/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/mensajes",
			consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
	@ResponseStatus(HttpStatus.CREATED)
	public MensajeProyectoAulaVista enviarMensajeAlReporte(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @AuthenticationPrincipal String usuarioId,
			@RequestParam(value = "texto", required = false) String texto,
			@RequestPart(value = "archivo", required = false) MultipartFile archivo) {
		MensajeProyectoAulaVista mensaje = chat.registrarMensajeProyecto(
				tutoriaId, proyectoId, sesionId, usuarioId, texto, archivo);
		chatRedis.publish(tutoriaId, proyectoId, sesionId, mensaje);
		return mensaje;
	}

	@GetMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/mensajes/{mensajeId}/archivo")
	public ResponseEntity<byte[]> descargarAdjuntoDelReporte(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @PathVariable String mensajeId,
			@AuthenticationPrincipal String usuarioId) {
		MensajeProyectoAula mensaje = chat.descargarArchivoProyecto(
				tutoriaId, proyectoId, sesionId, mensajeId, usuarioId);
		return ResponseEntity.ok()
				.contentType(MediaType.parseMediaType(mensaje.archivoMime()))
				.header("X-Content-Type-Options", "nosniff")
				.header(HttpHeaders.CONTENT_DISPOSITION, org.springframework.http.ContentDisposition.attachment()
						.filename(mensaje.archivoNombre(), StandardCharsets.UTF_8).build().toString())
				.contentLength(mensaje.archivoTamano())
				.body(mensaje.archivoContenido());
	}

	@GetMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/reunion")
	public com.pa.searchteach.tutorias.model.RespuestaReunionProyectoAula consultarReunion(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@AuthenticationPrincipal String usuarioId) {
		return reuniones.consultarReunion(tutoriaId, proyectoId, sesionId, usuarioId);
	}
}
