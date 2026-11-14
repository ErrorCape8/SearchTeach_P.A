package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/** Informe general que el docente líder envía a coordinación al terminar todos los proyectos del grupo. */
@Document(collection = "informes_avance_proyecto")
public record InformeAvanceProyecto(
		@Id String id,
		@NotBlank String tutoriaColectivaId,
		@NotBlank String docenteLiderId,
		@NotBlank @Size(max = 12000) String contenido,
		@NotNull LocalDateTime fechaInforme) {

	public InformeAvanceProyecto {
		if (tutoriaColectivaId == null || tutoriaColectivaId.isBlank()
				|| docenteLiderId == null || docenteLiderId.isBlank()) {
			throw new IllegalArgumentException("La tutoría y el docente líder son obligatorios.");
		}
		if (contenido == null || contenido.isBlank() || contenido.length() > 12000) {
			throw new IllegalArgumentException("El informe es obligatorio y no debe superar 12000 caracteres.");
		}
		if (fechaInforme == null) {
			throw new IllegalArgumentException("La fecha del informe es obligatoria.");
		}
	}
}
