package com.pa.searchteach.tutorias.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Positive;
import com.fasterxml.jackson.annotation.JsonIgnore;
import java.util.List;

public record ProyectoAula(
		String proyectoId,
		@NotBlank String nombre,
		@NotBlank String docenteResponsableId,
		@Size(max = 4) List<@NotBlank String> estudianteIds,
		@NotBlank String tecnologia,
		@Positive int semestre,
		@JsonIgnore String codigoInscripcion,
		@JsonIgnore String creadorId) {

	public ProyectoAula {
		if (proyectoId == null || proyectoId.isBlank()) {
			throw new IllegalArgumentException("El identificador del proyecto es obligatorio.");
		}
		if (nombre == null || nombre.isBlank()
				|| docenteResponsableId == null || docenteResponsableId.isBlank()
				|| tecnologia == null || tecnologia.isBlank() || semestre < 1 || semestre > 6) {
			throw new IllegalArgumentException("Los datos del proyecto deben estar completos.");
		}
		estudianteIds = estudianteIds == null ? List.of() : List.copyOf(estudianteIds);
		if (estudianteIds.size() > 4 || estudianteIds.stream().anyMatch(id -> id == null || id.isBlank())
				|| estudianteIds.stream().distinct().count() != estudianteIds.size()) {
			throw new IllegalArgumentException("La inscripciÃ³n admite hasta cuatro estudiantes distintos.");
		}
	}

	public ProyectoAula inscribir(String estudianteId) {
		if (estudianteIds.contains(estudianteId)) return this;
		if (estudianteIds.size() >= 4) throw new IllegalArgumentException("El grupo ya tiene cuatro estudiantes.");
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId,
				java.util.stream.Stream.concat(estudianteIds.stream(), java.util.stream.Stream.of(estudianteId)).toList(),
				tecnologia, semestre, codigoInscripcion, creadorId);
	}

	public ProyectoAula desistir(String estudianteId) {
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId,
				estudianteIds.stream().filter(id -> !id.equals(estudianteId)).toList(), tecnologia, semestre,
				codigoInscripcion, creadorId);
	}
}
