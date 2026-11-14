package com.pa.searchteach.tutorias.dto.colectivas;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record InformeGeneralSolicitud(@NotBlank @Size(max = 12000) String contenido) {}
