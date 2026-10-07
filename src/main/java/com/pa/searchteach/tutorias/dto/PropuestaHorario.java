package com.pa.searchteach.tutorias.dto;

import java.time.LocalDateTime;

import jakarta.validation.constraints.NotNull;

public record PropuestaHorario(
		@NotNull LocalDateTime fechaInicio,
		@NotNull LocalDateTime fechaFin) {
}
