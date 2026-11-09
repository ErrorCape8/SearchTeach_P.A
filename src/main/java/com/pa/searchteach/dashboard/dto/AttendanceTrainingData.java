package com.pa.searchteach.dashboard.dto;

public record AttendanceTrainingData(
		long registrosEtiquetados,
		long asistencias,
		long inasistencias,
		long registrosSinEtiqueta) {
}
