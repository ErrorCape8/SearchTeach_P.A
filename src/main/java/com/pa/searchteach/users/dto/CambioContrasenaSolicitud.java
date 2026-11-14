package com.pa.searchteach.users.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CambioContrasenaSolicitud(
		@NotBlank @Size(min = 8, max = 72) String nuevaContrasena,
		@NotBlank String confirmarContrasena) {
}
