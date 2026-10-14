package com.pa.searchteach.users.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CambioContrasenaSolicitud(
		@NotBlank String contrasenaActual,
		@NotBlank @Size(min = 8, max = 100) String nuevaContrasena) {
}
