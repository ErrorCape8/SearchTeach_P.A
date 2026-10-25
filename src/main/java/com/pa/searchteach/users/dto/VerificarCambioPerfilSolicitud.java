package com.pa.searchteach.users.dto;

import jakarta.validation.constraints.Pattern;

public record VerificarCambioPerfilSolicitud(
		@Pattern(regexp = "[0-9]{6}", message = "El código debe tener seis dígitos.") String codigo) {}
