package com.pa.searchteach.users.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record AplicarCambioPerfilSolicitud(
		@NotBlank @Size(max = 256) String nuevoValor) {}
