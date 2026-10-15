package com.pa.searchteach.dashboard.dto;

import java.util.List;

public record PronosticoDemanda(
		List<WeeklyTutoringCount> historialSolicitudes,
		long estimadoProximaSemana,
		long minimoProximaSemana,
		long maximoProximaSemana,
		long estimadoProximasCuatroSemanas,
		long minimoProximasCuatroSemanas,
		long maximoProximasCuatroSemanas,
		String tendencia,
		boolean alertaCreciente,
		String modelo) {
}
