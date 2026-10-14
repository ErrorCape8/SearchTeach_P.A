package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record TutoriaColectivaSolicitud(
		@NotBlank String docenteLiderId,
		@NotEmpty @Size(min = 5, max = 5) java.util.List<@NotBlank String> docentesApoyoIds,
		@NotBlank String tecnologia,
		@Min(1) @Max(6) int semestre) {
}
