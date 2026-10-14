package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record InformeAvanceSolicitud(
		@NotNull @Min(0) @Max(100) Integer puntajeAvance,
		@NotBlank @Size(max = 2000) String observaciones) {
}
