package com.pa.searchteach.tutorias.dto.grupal;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record SolicitudCambioFechaTutoria(
		@NotBlank @Size(max = 1000) String motivo) {
}
