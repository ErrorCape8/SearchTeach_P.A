package com.pa.searchteach.users.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

public record ActualizarSemestreSolicitud(@Min(1) @Max(6) int semestre) {
}
