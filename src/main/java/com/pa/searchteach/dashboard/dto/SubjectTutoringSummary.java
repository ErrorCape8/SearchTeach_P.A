package com.pa.searchteach.dashboard.dto;

public record SubjectTutoringSummary(
		String materia,
		long totalTutorias,
		long tutoriasRealizadas,
		Double tasaAsistencia) {
}
