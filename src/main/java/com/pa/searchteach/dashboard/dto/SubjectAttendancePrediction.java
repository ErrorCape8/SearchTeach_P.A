package com.pa.searchteach.dashboard.dto;

public record SubjectAttendancePrediction(
		String materia,
		String carrera,
		Integer semestre,
		long tutoriasEvaluadas,
		long asistenciasPredichas,
		long inasistenciasPredichas,
		Double probabilidadAsistenciaPromedio) {

	public SubjectAttendancePrediction(
			String materia,
			long tutoriasEvaluadas,
			long asistenciasPredichas,
			long inasistenciasPredichas,
			Double probabilidadAsistenciaPromedio) {
		this(materia, null, null, tutoriasEvaluadas, asistenciasPredichas, inasistenciasPredichas,
				probabilidadAsistenciaPromedio);
	}
}
