package com.pa.searchteach.tutorias.dto;

import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record ProyectoAulaSolicitud(
		@NotBlank String nombre,
		@NotBlank String docenteResponsableId,
		@NotEmpty @Size(min = 4, max = 4) List<@NotBlank String> estudianteIds,
		@NotBlank String tecnologia,
		@Positive int semestre) {
}
