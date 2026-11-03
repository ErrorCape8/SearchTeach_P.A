package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CierreProyectoAulaSolicitud(
		@NotBlank String motivo,
		@NotBlank @Size(max = 4000) String reporte) {}
