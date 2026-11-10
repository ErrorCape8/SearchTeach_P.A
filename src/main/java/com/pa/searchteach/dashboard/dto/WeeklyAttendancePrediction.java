package com.pa.searchteach.dashboard.dto;

import java.time.LocalDate;

public record WeeklyAttendancePrediction(
		LocalDate semanaInicio,
		long tutoriasEvaluadas,
		long asistenciasPredichas,
		long inasistenciasPredichas,
		Double probabilidadAsistenciaPromedio) {
}
