package com.pa.searchteach.dashboard.dto;

public record SubjectAttendancePrediction(
		String materia,
		long tutoriasEvaluadas,
		long asistenciasPredichas,
		long inasistenciasPredichas,
		Double probabilidadAsistenciaPromedio) {
}
