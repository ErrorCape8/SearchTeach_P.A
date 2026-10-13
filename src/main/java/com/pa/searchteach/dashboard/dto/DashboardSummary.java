package com.pa.searchteach.dashboard.dto;

import java.util.List;

public record DashboardSummary(
		long totalTutorias,
		long tutoriasRealizadas,
		long tutoriasProgramadas,
		Double tasaAsistencia,
		List<WeeklyTutoringCount> historialSemanal) {
}
