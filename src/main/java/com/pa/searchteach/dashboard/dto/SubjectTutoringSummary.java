package com.pa.searchteach.dashboard.dto;

public record SubjectTutoringSummary(
		String materia,
		long totalTutorias,
		long tutoriasRealizadas,
		long estudiantesInscritos,
		long asistenciasConfirmadas,
		long asistenciasRegistradas,
		Double tasaAsistencia,
		PronosticoDemanda pronostico) {
}
