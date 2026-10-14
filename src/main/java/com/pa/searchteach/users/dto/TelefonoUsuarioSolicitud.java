package com.pa.searchteach.users.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record TelefonoUsuarioSolicitud(
		@NotBlank @Size(max = 30) String telefono) {
}
