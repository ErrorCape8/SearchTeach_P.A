package com.pa.searchteach.tutorias.dto;

import java.time.LocalDateTime;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record SolicitudCambioFechaTutoria(
		@NotNull LocalDateTime fechaInicio,
		@NotNull LocalDateTime fechaFin,
		@NotBlank @Size(max = 1000) String motivo) {
}
