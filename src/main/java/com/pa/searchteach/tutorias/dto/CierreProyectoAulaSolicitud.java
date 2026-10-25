package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.NotBlank;

public record CierreProyectoAulaSolicitud(@NotBlank String motivo) {}
