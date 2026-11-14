package com.pa.searchteach.users.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record TelefonoUsuarioSolicitud(
		@NotBlank @Pattern(regexp = "[0-9+()\\-\\s]{7,30}") String telefono) {
}
