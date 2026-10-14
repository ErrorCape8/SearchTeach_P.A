package com.pa.searchteach.tutorias.dto;

public record PronosticoMejoraProyecto(
		String tendencia,
		int informesEvaluados,
		Double puntajeActual,
		Double puntajePronosticadoEnCuatroSemanas,
		Double cambioPronosticado) {
}
