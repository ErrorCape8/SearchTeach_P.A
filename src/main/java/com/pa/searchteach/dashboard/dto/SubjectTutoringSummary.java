package com.pa.searchteach.dashboard.dto;

import java.util.List;

public record SubjectTutoringSummary(
		String materia,
		List<String> carreras,
		List<Integer> semestres,
		long totalTutorias,
		long tutoriasRealizadas,
		long estudiantesInscritos,
		long asistenciasConfirmadas,
		long asistenciasRegistradas,
		Double tasaAsistencia) {

	public SubjectTutoringSummary(
			String materia,
			long totalTutorias,
			long tutoriasRealizadas,
			long estudiantesInscritos,
			long asistenciasConfirmadas,
			long asistenciasRegistradas,
			Double tasaAsistencia) {
		this(
				materia,
				List.of(),
				List.of(),
				totalTutorias,
				tutoriasRealizadas,
				estudiantesInscritos,
				asistenciasConfirmadas,
				asistenciasRegistradas,
				tasaAsistencia);
	}
}
