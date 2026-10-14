package com.pa.searchteach.tutorias.modelo;

import java.time.LocalDateTime;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "informes_avance_proyecto")
public record InformeAvanceProyecto(
		@Id String id,
		@NotBlank String tutoriaColectivaId,
		@NotBlank String proyectoId,
		@NotBlank String docenteId,
		@NotNull @Min(0) @Max(100) Integer puntajeAvance,
		@NotBlank @Size(max = 2000) String observaciones,
		@NotNull LocalDateTime fechaInforme) {

	public InformeAvanceProyecto {
		if (tutoriaColectivaId == null || tutoriaColectivaId.isBlank()
				|| proyectoId == null || proyectoId.isBlank()
				|| docenteId == null || docenteId.isBlank()) {
			throw new IllegalArgumentException("La tutoría, el proyecto y el docente son obligatorios.");
		}
		if (puntajeAvance == null || puntajeAvance < 0 || puntajeAvance > 100) {
			throw new IllegalArgumentException("El puntaje de avance debe estar entre 0 y 100.");
		}
		if (observaciones == null || observaciones.isBlank() || observaciones.length() > 2000) {
			throw new IllegalArgumentException("Las observaciones son obligatorias y no deben superar 2000 caracteres.");
		}
		if (fechaInforme == null) {
			throw new IllegalArgumentException("La fecha del informe es obligatoria.");
		}
	}
}
