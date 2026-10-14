package com.pa.searchteach.tutorias.modelo;

import java.time.LocalDateTime;
import java.util.HashSet;
import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "tutorias_colectivas")
public record TutoriaColectiva(
		@Id String id,
		@NotBlank String coordinadoraId,
		@NotBlank String docenteLiderId,
		@NotEmpty @Size(min = 5, max = 5) List<@NotBlank String> docentesApoyoIds,
		String tecnologia,
		int semestre,
		List<@NotNull ProyectoAula> proyectos,
		@NotNull LocalDateTime creadaEn) {

	public TutoriaColectiva {
		if (coordinadoraId == null || coordinadoraId.isBlank()
				|| docenteLiderId == null || docenteLiderId.isBlank()) {
			throw new IllegalArgumentException("La coordinadora y el docente líder son obligatorios.");
		}
		if (docentesApoyoIds == null || docentesApoyoIds.size() != 5
				|| docentesApoyoIds.stream().anyMatch(docenteId -> docenteId == null || docenteId.isBlank())
				|| new HashSet<>(docentesApoyoIds).size() != 5
				|| docentesApoyoIds.contains(docenteLiderId)) {
			throw new IllegalArgumentException(
					"Debe asignarse un docente líder y cinco docentes de apoyo distintos.");
		}
		HashSet<String> conjuntoDocentesApoyo = new HashSet<>(docentesApoyoIds);
		if ((tecnologia != null && !tecnologia.isBlank()
				&& (semestre < 1 || semestre > 6))
				|| (tecnologia != null && tecnologia.isBlank())
				|| proyectos == null
				|| proyectos.stream().anyMatch(proyecto -> proyecto == null)
				|| proyectos.stream().map(ProyectoAula::proyectoId).distinct().count() != proyectos.size()
				|| proyectos.stream()
						.anyMatch(proyecto -> !conjuntoDocentesApoyo.contains(proyecto.docenteResponsableId())
								&& !docenteLiderId.equals(proyecto.docenteResponsableId()))) {
			throw new IllegalArgumentException(
					"Los proyectos deben tener docentes responsables válidos.");
		}
		HashSet<String> todosLosEstudiantes = new HashSet<>();
		for (ProyectoAula proyecto : proyectos) {
			for (String estudianteId : proyecto.estudianteIds()) {
				if (!todosLosEstudiantes.add(estudianteId)) {
					throw new IllegalArgumentException(
							"Un estudiante no puede estar asignado a más de un proyecto del grupo.");
				}
			}
		}
		if (creadaEn == null) {
			throw new IllegalArgumentException("La fecha de creación es obligatoria.");
		}
		docentesApoyoIds = List.copyOf(docentesApoyoIds);
		proyectos = List.copyOf(proyectos);
	}

	public TutoriaColectiva actualizarProyecto(ProyectoAula actualizado) {
		List<ProyectoAula> nuevos = proyectos.stream()
				.map(proyecto -> proyecto.proyectoId().equals(actualizado.proyectoId()) ? actualizado : proyecto)
				.toList();
		if (proyectos.stream().noneMatch(proyecto -> proyecto.proyectoId().equals(actualizado.proyectoId()))) {
			nuevos = java.util.stream.Stream.concat(proyectos.stream(), java.util.stream.Stream.of(actualizado)).toList();
		}
		return new TutoriaColectiva(
				id, coordinadoraId, docenteLiderId, docentesApoyoIds, tecnologia, semestre, nuevos, creadaEn);
	}
}
