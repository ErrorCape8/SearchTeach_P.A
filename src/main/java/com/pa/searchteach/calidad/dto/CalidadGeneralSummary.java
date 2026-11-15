package com.pa.searchteach.calidad.dto;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;

public record CalidadGeneralSummary(
		Double promedioGeneral,
		long totalCalificaciones,
		Map<Integer, Long> distribucionEstrellas,
		List<MateriaCalidadDto> calificacionPorMateria,
		List<CalificacionAnonimaDto> comentariosRecientes,
		List<ComentarioFrecuenteDto> comentariosFrecuentes) {

	public record MateriaCalidadDto(
			String materia,
			Double promedioEstrellas,
			long totalCalificaciones) {
	}

	public record CalificacionAnonimaDto(
			int estrellas,
			String materia,
			String comentario,
			LocalDateTime fecha) {
	}

	public record ComentarioFrecuenteDto(
			String comentario,
			long veces) {
	}
}
