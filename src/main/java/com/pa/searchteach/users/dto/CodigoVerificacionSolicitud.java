package com.pa.searchteach.users.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record CodigoVerificacionSolicitud(
		@NotBlank @Pattern(regexp = "[0-9]{6}") String code) {
}
