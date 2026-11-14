package com.pa.searchteach.tutorias.dto.grupal;

import java.time.LocalDateTime;
import jakarta.validation.constraints.NotBlank;

public record ResolverSolicitudCambioFecha(
		@NotBlank String accion,
		LocalDateTime fechaInicio,
		String motivoDenegacion) {
}
