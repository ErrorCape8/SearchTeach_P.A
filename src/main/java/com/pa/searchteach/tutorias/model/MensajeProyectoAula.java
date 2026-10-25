package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "mensajes_proyecto_aula")
public record MensajeProyectoAula(
		@Id String id,
		@NotBlank String tutoriaColectivaId,
		@NotBlank String proyectoId,
		@NotBlank String sesionId,
		@NotBlank String emisorId,
		String texto,
		String archivoNombre,
		String archivoMime,
		Long archivoTamano,
		@JsonIgnore byte[] archivoContenido,
		@NotNull LocalDateTime enviadoEn,
		String tipo,
		String reunionRoomId) {

	public MensajeProyectoAula(String id, String tutoriaColectivaId, String proyectoId, String sesionId,
			String emisorId, String texto, String archivoNombre, String archivoMime, Long archivoTamano,
			byte[] archivoContenido, LocalDateTime enviadoEn) {
		this(id, tutoriaColectivaId, proyectoId, sesionId, emisorId, texto, archivoNombre,
				archivoMime, archivoTamano, archivoContenido, enviadoEn, "CHAT", null);
	}
}
