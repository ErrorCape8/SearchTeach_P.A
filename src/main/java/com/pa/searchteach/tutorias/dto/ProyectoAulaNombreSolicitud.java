package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Size;

public record ProyectoAulaNombreSolicitud(
		@NotBlank @Size(max = 120) String nombre,
		@Min(1) @Max(6) int semestre) {
}
