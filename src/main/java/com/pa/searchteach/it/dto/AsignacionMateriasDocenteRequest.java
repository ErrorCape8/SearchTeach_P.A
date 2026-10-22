package com.pa.searchteach.it.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record AsignacionMateriasDocenteRequest(
		@NotEmpty List<@NotBlank String> titulosAcademicos,
		@NotEmpty List<@NotBlank String> materiasAsignadas) {
}