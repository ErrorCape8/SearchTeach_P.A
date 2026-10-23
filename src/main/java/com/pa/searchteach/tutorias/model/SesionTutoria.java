package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "sesiones_tutoria")
public record SesionTutoria(
		@Id String id,
		@NotBlank String docenteId,
		@Size(max = 5) List<@NotBlank String> estudianteIds,
		@NotNull LocalDateTime fechaInicio,
		@NotNull LocalDateTime fechaFin,
		@NotBlank String tecnologia,
		@Positive int semestre,
		@Size(max = 5) List<AsistenciaEstudiante> asistencias,
		String materia,
		List<@NotBlank String> tecnologias) {

	public SesionTutoria {
		if (docenteId == null || docenteId.isBlank()) {
			throw new IllegalArgumentException("El id del docente es obligatorio.");
		}
		if (estudianteIds == null || estudianteIds.size() > 5) {
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
		if (tecnologias == null || tecnologias.isEmpty()) {
			tecnologias = List.of(tecnologia);
		} else {
			if (tecnologias.stream().anyMatch(item -> item == null || item.isBlank())) {
				throw new IllegalArgumentException("Las tecnologías de la sesión deben ser válidas.");
			}
			tecnologias = tecnologias.stream().map(String::trim).distinct().toList();
			if (!tecnologias.contains(tecnologia)) {
				tecnologias = java.util.stream.Stream.concat(tecnologias.stream(), java.util.stream.Stream.of(tecnologia))
						.distinct().toList();
			}
		}
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
				null, docenteId, estudianteIds, fechaInicio, fechaFin, tecnologia, semestre, asistencias,
				null, List.of(tecnologia));
	}

	public static SesionTutoria crearDisponible(
			String docenteId,
			LocalDateTime fechaInicio,
			LocalDateTime fechaFin,
			String materia,
			String tecnologia,
			int semestre) {
		return new SesionTutoria(null, docenteId, List.of(), fechaInicio, fechaFin, tecnologia, semestre,
				List.of(), materia, List.of(tecnologia));
	}

	public static SesionTutoria crear(///cambiar nombre del metodo a crearSesionTutoriaColectiva
			String docenteId,
			List<String> estudianteIds,
			LocalDateTime fechaInicio,
			LocalDateTime fechaFin,
			String materia,
			List<String> tecnologias,
			String tecnologiaPrincipal,
			int semestre) {
		List<AsistenciaEstudiante> asistencias = estudianteIds == null
				? List.of()
				: estudianteIds.stream()
						.map(estudianteId -> new AsistenciaEstudiante(estudianteId, null))
						.toList();
		return new SesionTutoria(null, docenteId, estudianteIds, fechaInicio, fechaFin,
				tecnologiaPrincipal, semestre, asistencias, materia, tecnologias);
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
				asistenciasActualizadas,
				materia,
				tecnologias);
	}

	public SesionTutoria inscribir(String estudianteId, String tecnologiaEstudiante) {
		if (estudianteIds.contains(estudianteId)) return this;
		if (estudianteIds.size() >= 5) {
			throw new IllegalArgumentException("La sesiÃ³n ya alcanzÃ³ su cupo de cinco estudiantes.");
		}
		List<String> nuevosEstudiantes = java.util.stream.Stream
				.concat(estudianteIds.stream(), java.util.stream.Stream.of(estudianteId)).toList();
		List<AsistenciaEstudiante> nuevasAsistencias = java.util.stream.Stream
				.concat(asistencias.stream(), java.util.stream.Stream.of(new AsistenciaEstudiante(estudianteId, null)))
				.toList();
		List<String> nuevasTecnologias = java.util.stream.Stream
				.concat(tecnologias.stream(), java.util.stream.Stream.of(tecnologiaEstudiante))
				.distinct().toList();
		return new SesionTutoria(id, docenteId, nuevosEstudiantes, fechaInicio, fechaFin,
				tecnologia, semestre, nuevasAsistencias, materia, nuevasTecnologias);
	}

	public SesionTutoria desistir(String estudianteId) {
		List<String> nuevosEstudiantes = estudianteIds.stream()
				.filter(actual -> !actual.equals(estudianteId)).toList();
		List<AsistenciaEstudiante> nuevasAsistencias = asistencias.stream()
				.filter(actual -> !actual.estudianteId().equals(estudianteId)).toList();
		return new SesionTutoria(id, docenteId, nuevosEstudiantes, fechaInicio, fechaFin,
				tecnologia, semestre, nuevasAsistencias, materia, tecnologias);
	}
}
