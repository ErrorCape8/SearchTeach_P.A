package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;
import java.util.Map;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "respuestas_reunion_proyecto_aula")
public record RespuestaReunionProyectoAula(
		@Id String id,
		@NotBlank String tutoriaColectivaId,
		@NotBlank String proyectoId,
		@NotBlank String sesionId,
		@NotNull LocalDateTime fechaReunion,
		@NotBlank String propuestaPorId,
		@NotNull Map<String, Boolean> respuestas,
		@NotBlank String estado,
		@NotNull LocalDateTime actualizadaEn) {
}
