package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ProyectoAulaNombreSolicitud(
		@NotBlank @Size(max = 120) String nombre) {
}
