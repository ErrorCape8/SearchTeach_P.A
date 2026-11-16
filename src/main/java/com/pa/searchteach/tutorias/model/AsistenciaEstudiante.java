package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;

import org.springframework.data.mongodb.core.mapping.Field;

public record AsistenciaEstudiante(
		@Field("estudianteId") String estudianteId,
		@Field("asistio") Boolean asistio,
		@Field("estado") String estado,
		@Field("minutosTarde") Integer minutosTarde,
		@Field("ingresoEn") LocalDateTime ingresoEn) {

	public AsistenciaEstudiante(String estudianteId, Boolean asistio) {
		this(estudianteId, asistio, null, null, null);
	}

	public AsistenciaEstudiante {
		if (estudianteId == null || estudianteId.isBlank()) {
			throw new IllegalArgumentException("El id del estudiante es obligatorio.");
		}
	}
}
