package com.pa.searchteach.dashboard.dto;

public record PaDashboardSummary(
		long totalTutoriasPa,
		long tutoriasPaRealizadas,
		long tutoriasPaProgramadas,
		Double tasaAsistenciaPa,
		long tutoriasPaEvaluadas,
		long asistenciasPaPredichas,
		Double probabilidadAsistenciaPaPromedio) {
}
