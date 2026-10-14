package com.pa.searchteach.tutorias.modelo;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "sesiones_tutoria")
public record SesionTutoria(
		@Id String id,
		@NotBlank String docenteId,
		@NotEmpty @Size(max = 5) List<@NotBlank String> estudianteIds,
		@NotNull LocalDateTime fechaInicio,
		@NotNull LocalDateTime fechaFin,
		@NotBlank String tecnologia,
		@Positive int semestre,
		@NotEmpty List<AsistenciaEstudiante> asistencias) {

	public SesionTutoria {
		if (docenteId == null || docenteId.isBlank()) {
			throw new IllegalArgumentException("El id del docente es obligatorio.");
		}
		if (estudianteIds == null || estudianteIds.isEmpty() || estudianteIds.size() > 5) {
			throw new IllegalArgumentException("La sesión debe tener entre 1 y 5 estudiantes.");
		}
		estudianteIds = List.copyOf(estudianteIds);
		if (estudianteIds.stream().anyMatch(estudianteId -> estudianteId == null || estudianteId.isBlank())
				|| new HashSet<>(estudianteIds).size() != estudianteIds.size()) {
			throw new IllegalArgumentException("Los ids de estudiantes deben ser únicos y válidos.");
		}
		if (fechaInicio == null || fechaFin == null || !fechaFin.isAfter(fechaInicio)) {
			throw new IllegalArgumentException("La fecha final debe ser posterior a la fecha inicial.");
		}
		if (tecnologia == null || tecnologia.isBlank()) {
			throw new IllegalArgumentException("La tecnología es obligatoria.");
		}
		if (semestre < 1) {
			throw new IllegalArgumentException("El semestre debe ser mayor que cero.");
		}
		if (asistencias == null || asistencias.size() != estudianteIds.size()) {
			throw new IllegalArgumentException("Debe existir un registro de asistencia por estudiante.");
		}
		asistencias = List.copyOf(asistencias);
		Set<String> estudiantesConAsistencia = new HashSet<>();
		for (AsistenciaEstudiante asistencia : asistencias) {
			if (asistencia == null || !estudianteIds.contains(asistencia.estudianteId())
					|| !estudiantesConAsistencia.add(asistencia.estudianteId())) {
				throw new IllegalArgumentException(
						"Las asistencias deben corresponder una sola vez a cada estudiante de la sesión.");
			}
		}
	}

	public static SesionTutoria crear(
			String docenteId,
			List<String> estudianteIds,
			LocalDateTime fechaInicio,
			LocalDateTime fechaFin,
			String tecnologia,
			int semestre) {
		List<AsistenciaEstudiante> asistencias = estudianteIds == null
				? List.of()
				: estudianteIds.stream()
						.map(estudianteId -> new AsistenciaEstudiante(estudianteId, null))
						.toList();
		return new SesionTutoria(
				null, docenteId, estudianteIds, fechaInicio, fechaFin, tecnologia, semestre, asistencias);
	}

	public SesionTutoria registrarAsistencia(String estudianteId, boolean asistio) {
		List<AsistenciaEstudiante> asistenciasActualizadas = asistencias.stream()
				.map(asistencia -> asistencia.estudianteId().equals(estudianteId)
						? new AsistenciaEstudiante(estudianteId, asistio)
						: asistencia)
				.toList();
		if (asistenciasActualizadas.stream().noneMatch(
				asistencia -> asistencia.estudianteId().equals(estudianteId))) {
			throw new IllegalArgumentException("El estudiante no pertenece a esta sesión.");
		}
		return new SesionTutoria(
				id,
				docenteId,
				estudianteIds,
				fechaInicio,
				fechaFin,
				tecnologia,
				semestre,
				asistenciasActualizadas);
	}
}
