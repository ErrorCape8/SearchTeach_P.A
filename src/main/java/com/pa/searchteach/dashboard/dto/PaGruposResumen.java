package com.pa.searchteach.dashboard.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/** Pronóstico semanal de grupos nuevos de Proyecto de Aula y su historial. */
public record PaGruposResumen(
		boolean modeloDisponible,
		List<Prediccion> predicciones,
		List<SemanaGrupos> historial) {

	/** Predicción de la semana actual para una carrera. */
	public record Prediccion(
			String carrera,
			LocalDate semanaInicio,
			int semanaDelAnio,
			long nuevosSemanaAnterior,
			double promedioUltimas3Semanas,
			long estudiantesSinGrupos,
			String clasePredicha,
			double probabilidadClase,
			double gruposEsperados,
			Map<String, Double> probabilidades) {
	}

	/** Grupos (proyectos) creados en una semana por carrera. */
	public record SemanaGrupos(LocalDate semanaInicio, String carrera, long nuevos) {
	}
}
