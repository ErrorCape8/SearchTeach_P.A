package com.pa.searchteach.tutorias.dto;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Size;

public record TutoriaColectivaSolicitud(
		@NotBlank String docenteLiderId,
		@NotEmpty @Size(min = 5, max = 5) List<@NotBlank String> docentesApoyoIds,
		@NotEmpty @Size(min = 5, max = 5) List<@Valid ProyectoAulaSolicitud> proyectos) {
}
