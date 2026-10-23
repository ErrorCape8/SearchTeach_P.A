package com.pa.searchteach.tutorias.dto;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public record ProgramarTutoriasSolicitud(
		@NotBlank String tecnologia,
		@Positive int semestre,
		@NotEmpty List<@Valid Bloque> bloques) {

	public record Bloque(
			@NotBlank String docenteId,
			@NotBlank String materia,
			@NotNull ModalidadTutoria modalidad,
			@NotNull LocalDateTime fechaInicio,
			@NotNull LocalDateTime fechaFin) {
	}
}
