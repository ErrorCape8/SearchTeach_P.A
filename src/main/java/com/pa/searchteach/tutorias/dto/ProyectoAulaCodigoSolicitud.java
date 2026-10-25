package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.Pattern;

public record ProyectoAulaCodigoSolicitud(@Pattern(regexp = "\\d{6}") String codigo) {
}
