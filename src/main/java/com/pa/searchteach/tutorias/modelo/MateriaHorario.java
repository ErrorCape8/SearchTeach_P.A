package com.pa.searchteach.tutorias.modelo;

import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

public record MateriaHorario(
		@NotBlank String nombre,
		@NotEmpty List<@NotBlank String> carreras) {

	public MateriaHorario {
		if (nombre == null || nombre.isBlank() || carreras == null || carreras.isEmpty()
				|| carreras.stream().anyMatch(carrera -> carrera == null || carrera.isBlank())) {
			throw new IllegalArgumentException("La materia debe tener nombre y al menos una tecnología.");
		}
		carreras = carreras.stream().map(String::trim).distinct().toList();
	}
}
