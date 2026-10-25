package com.pa.searchteach.tutorias.dto;

import java.time.LocalDateTime;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record SesionProyectoAulaSolicitud(
		@NotNull LocalDateTime fechaInicio,
		@NotNull LocalDateTime fechaFin,
		@NotBlank @Size(max = 12000) String contenido) {
}
