package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;

public record ProyectoAulaSolicitud(
		@NotBlank String nombre,
		@NotBlank String docenteResponsableId,
		@NotBlank String tecnologia,
		@Positive int semestre) {
}
