package com.pa.searchteach.tutorias.modelo;

import java.util.HashSet;
import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

public record ProyectoAula(
		String proyectoId,
		@NotBlank String nombre,
		@NotBlank String docenteResponsableId,
		@NotEmpty @Size(min = 4, max = 4) List<@NotBlank String> estudianteIds,
		@NotBlank String tecnologia,
		@Positive int semestre) {

	public ProyectoAula {
		if (proyectoId == null || proyectoId.isBlank()) {
			throw new IllegalArgumentException("El identificador del proyecto es obligatorio.");
		}
		if (nombre == null || nombre.isBlank()
				|| docenteResponsableId == null || docenteResponsableId.isBlank()
				|| tecnologia == null || tecnologia.isBlank() || semestre < 1) {
			throw new IllegalArgumentException("Los datos del proyecto deben estar completos.");
		}
		if (estudianteIds == null || estudianteIds.size() != 4
				|| estudianteIds.stream().anyMatch(id -> id == null || id.isBlank())
				|| new HashSet<>(estudianteIds).size() != estudianteIds.size()) {
			throw new IllegalArgumentException("Cada proyecto debe tener cuatro estudiantes distintos.");
		}
		estudianteIds = List.copyOf(estudianteIds);
	}
}
