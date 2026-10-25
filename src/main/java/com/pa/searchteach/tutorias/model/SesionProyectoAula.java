package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "sesiones_proyecto_aula")
public record SesionProyectoAula(
		@Id String id,
		@NotBlank String tutoriaColectivaId,
		@NotBlank String proyectoId,
		@NotBlank String docenteId,
		@NotNull LocalDateTime fechaInicio,
		@NotNull LocalDateTime fechaFin,
		@NotBlank @Size(max = 12000) String contenido,
		@NotNull LocalDateTime guardadaEn,
		String confirmadoPorLiderId,
		LocalDateTime confirmadoEn) {

	public SesionProyectoAula(String id, String tutoriaColectivaId, String proyectoId, String docenteId,
			LocalDateTime fechaInicio, LocalDateTime fechaFin, String contenido, LocalDateTime guardadaEn) {
		this(id, tutoriaColectivaId, proyectoId, docenteId, fechaInicio, fechaFin, contenido, guardadaEn, null, null);
	}

	public SesionProyectoAula {
		if (tutoriaColectivaId == null || tutoriaColectivaId.isBlank()
				|| proyectoId == null || proyectoId.isBlank()
				|| docenteId == null || docenteId.isBlank()
				|| fechaInicio == null || fechaFin == null || !fechaFin.isAfter(fechaInicio)
				|| contenido == null || contenido.isBlank() || contenido.length() > 12000
				|| guardadaEn == null) {
			throw new IllegalArgumentException("Completa el horario y las notas de la sesión de proyecto.");
		}
	}

	public SesionProyectoAula confirmar(String docenteLiderId, LocalDateTime fecha) {
		return new SesionProyectoAula(id, tutoriaColectivaId, proyectoId, docenteId, fechaInicio,
				fechaFin, contenido, guardadaEn, docenteLiderId, fecha);
	}
}
