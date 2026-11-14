package com.pa.searchteach.tutorias.service.colectivas;

import java.time.LocalDateTime;
import java.io.IOException;
import java.util.List;
import java.util.UUID;
import java.util.Locale;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.tutorias.dto.colectivas.MensajeProyectoAulaVista;
import com.pa.searchteach.tutorias.model.MensajeProyectoAula;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.repository.MensajeProyectoAulaRepositorio;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.multipart.MultipartFile;

/** Mensajes y adjuntos del chat de un reporte de proyecto de aula. */
@Service
public class ChatProyectoAulaService {

	private final MensajeProyectoAulaRepositorio mensajeProyectoRepositorio;
	private final BusquedaProyectosAula busqueda;

	public ChatProyectoAulaService(
			MensajeProyectoAulaRepositorio mensajeProyectoRepositorio,
			BusquedaProyectosAula busqueda) {
		this.mensajeProyectoRepositorio = mensajeProyectoRepositorio;
		this.busqueda = busqueda;
	}

	public ProyectoAula obtenerProyectoEnChat(String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		busqueda.validarAccesoLecturaProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		return busqueda.buscarProyecto(busqueda.buscarTutoria(tutoriaId), proyectoId);
	}

	public void validarParticipanteProyecto(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		busqueda.validarAccesoParticipanteProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
	}

	public List<MensajeProyectoAulaVista> listarMensajesProyecto(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		busqueda.validarAccesoLecturaProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		return mensajeProyectoRepositorio
				.findByTutoriaColectivaIdAndProyectoIdAndSesionIdOrderByEnviadoEnAsc(
						tutoriaId, proyectoId, sesionId)
				.stream()
				.map(mensaje -> new MensajeProyectoAulaVista(
						mensaje.id(), mensaje.emisorId(), mensaje.emisorId().equals(usuarioId),
						mensaje.texto(), mensaje.archivoNombre(), mensaje.archivoMime(),
						mensaje.archivoTamano(), mensaje.enviadoEn(), mensaje.tipo(), mensaje.reunionRoomId()))
				.toList();
	}

	public MensajeProyectoAulaVista registrarMensajeProyecto(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId,
			String texto, MultipartFile archivo) {
		busqueda.validarAccesoParticipanteProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		if ("FINALIZADO".equals(busqueda.buscarProyecto(busqueda.buscarTutoria(tutoriaId), proyectoId).estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "El chat quedó cerrado al finalizar el proyecto.");
		}
		String contenido = texto == null ? "" : texto.trim();
		if (contenido.length() > 4000 || (contenido.isEmpty() && (archivo == null || archivo.isEmpty()))) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Escribe un mensaje o adjunta un archivo; el texto admite hasta 4000 caracteres.");
		}
		byte[] bytes = null;
		String nombre = null;
		String mime = null;
		if (archivo != null && !archivo.isEmpty()) {
			try {
				bytes = archivo.getBytes();
			} catch (IOException error) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No se pudo leer el archivo adjunto.");
			}
			if (bytes.length > 8 * 1024 * 1024) {
				throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "El archivo no puede superar 8 MB.");
			}
			String original = archivo.getOriginalFilename() == null ? "" : archivo.getOriginalFilename();
			nombre = original.replace('\\', '/');
			nombre = nombre.substring(nombre.lastIndexOf('/') + 1).replaceAll("[^A-Za-z0-9._ -]", "_");
			String extension = nombre.substring(nombre.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
			mime = switch (extension) {
				case "pdf" -> "application/pdf";
				case "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
				case "webm" -> "audio/webm";
				default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Solo se permiten archivos PDF, Word (.docx) o audio WebM.");
			};
			if (bytes.length > 8 * 1024 * 1024) {
				throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,
						"El archivo no puede superar 8 MB.");
			}
			if ("webm".equals(extension) && !ValidadorArchivosChat.archivoValidoAudioWebm(bytes)) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"El audio no tiene un contenedor WebM válido.");
			}
			if (!"webm".equals(extension) && !ValidadorArchivosChat.archivoValido(extension, bytes)) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"El contenido del archivo no coincide con su tipo permitido.");
			}
		}
		MensajeProyectoAula guardado = mensajeProyectoRepositorio.save(new MensajeProyectoAula(
				UUID.randomUUID().toString(), tutoriaId, proyectoId, sesionId, usuarioId,
				contenido, nombre, mime, bytes == null ? null : (long) bytes.length, bytes, LocalDateTime.now()));
		return new MensajeProyectoAulaVista(guardado.id(), guardado.emisorId(), true, guardado.texto(),
				guardado.archivoNombre(), guardado.archivoMime(), guardado.archivoTamano(), guardado.enviadoEn(),
				guardado.tipo(), guardado.reunionRoomId());
	}

	public MensajeProyectoAula descargarArchivoProyecto(
			String tutoriaId, String proyectoId, String sesionId, String mensajeId, String usuarioId) {
		busqueda.validarAccesoLecturaProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		return mensajeProyectoRepositorio
				.findByTutoriaColectivaIdAndProyectoIdAndSesionIdOrderByEnviadoEnAsc(
						tutoriaId, proyectoId, sesionId).stream()
				.filter(mensaje -> mensaje.id().equals(mensajeId) && mensaje.archivoContenido() != null)
				.findFirst()
				.orElseThrow(() -> new NotFoundException("No se encontró el archivo adjunto."));
	}
}
