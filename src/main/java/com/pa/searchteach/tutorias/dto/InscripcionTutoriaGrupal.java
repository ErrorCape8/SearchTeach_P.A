package com.pa.searchteach.tutorias.dto;

import java.time.LocalDateTime;

import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record InscripcionTutoriaGrupal(
		@NotBlank String docenteId,
		@NotBlank String materia,
		@NotNull ModalidadTutoria modalidad,
		@NotNull LocalDateTime fechaInicio,
		@NotNull LocalDateTime fechaFin,
		int semestre) {
}
