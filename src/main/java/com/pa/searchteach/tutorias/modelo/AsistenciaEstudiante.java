package com.pa.searchteach.tutorias.modelo;

import org.springframework.data.mongodb.core.mapping.Field;

public record AsistenciaEstudiante(
		@Field("estudianteId") String estudianteId,
		@Field("asistio") Boolean asistio) {

	public AsistenciaEstudiante {
		if (estudianteId == null || estudianteId.isBlank()) {
			throw new IllegalArgumentException("El id del estudiante es obligatorio.");
		}
	}
}
