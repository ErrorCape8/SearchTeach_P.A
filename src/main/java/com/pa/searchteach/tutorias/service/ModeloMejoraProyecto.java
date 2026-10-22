package com.pa.searchteach.tutorias.service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

import com.pa.searchteach.tutorias.dto.PronosticoMejoraProyecto;
import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;

public final class ModeloMejoraProyecto {

	private static final int MINIMO_PERIODOS = 3;
	private static final double CAMBIO_RELEVANTE = 2.0;

	private ModeloMejoraProyecto() {
	}

	public static PronosticoMejoraProyecto evaluar(List<InformeAvanceProyecto> informes) {
		TreeMap<LocalDate, List<InformeAvanceProyecto>> informesPorDia = informes.stream()
				.collect(java.util.stream.Collectors.groupingBy(
						informe -> informe.fechaInforme().toLocalDate(),
						TreeMap::new,
						java.util.stream.Collectors.toList()));
		if (informesPorDia.size() < MINIMO_PERIODOS) {
			return new PronosticoMejoraProyecto(
					"DATOS_INSUFICIENTES",
					informes.size(),
					informesPorDia.isEmpty() ? null : promedio(informesPorDia.lastEntry().getValue()),
					null,
					null);
		}

		List<Map.Entry<LocalDate, List<InformeAvanceProyecto>>> puntos =
				List.copyOf(informesPorDia.entrySet());
		LocalDate fechaInicial = puntos.getFirst().getKey();
		double promedioX = puntos.stream()
				.mapToDouble(punto -> ChronoUnit.DAYS.between(fechaInicial, punto.getKey()) / 7.0)
				.average()
				.orElse(0);
		double promedioY = puntos.stream()
				.mapToDouble(punto -> promedio(punto.getValue()))
				.average()
				.orElse(0);
		double sumaXX = 0;
		double sumaXY = 0;
		for (var punto : puntos) {
			double x = ChronoUnit.DAYS.between(fechaInicial, punto.getKey()) / 7.0;
			double y = promedio(punto.getValue());
			sumaXX += (x - promedioX) * (x - promedioX);
			sumaXY += (x - promedioX) * (y - promedioY);
		}
		if (sumaXX == 0) {
			return new PronosticoMejoraProyecto(
					"DATOS_INSUFICIENTES",
					informes.size(),
					promedio(puntos.getLast().getValue()),
					null,
					null);
		}

		double pendiente = sumaXY / sumaXX;
		double intercepto = promedioY - pendiente * promedioX;
		double semanaFinal = ChronoUnit.DAYS.between(fechaInicial, puntos.getLast().getKey()) / 7.0;
		double puntajeActual = promedio(puntos.getLast().getValue());
		double puntajeFuturo = limitarPuntaje(intercepto + pendiente * (semanaFinal + 4));
		double cambio = puntajeFuturo - puntajeActual;
		String tendencia = cambio >= CAMBIO_RELEVANTE
				? "MEJORA_PRONOSTICADA"
				: cambio <= -CAMBIO_RELEVANTE ? "RETROCESO_PRONOSTICADO" : "ESTABLE";

		return new PronosticoMejoraProyecto(
				tendencia,
				informes.size(),
				redondear(puntajeActual),
				redondear(puntajeFuturo),
				redondear(cambio));
	}

	private static double promedio(List<InformeAvanceProyecto> informes) {
		return informes.stream()
				.mapToInt(InformeAvanceProyecto::puntajeAvance)
				.average()
				.orElseThrow();
	}

	private static double limitarPuntaje(double puntaje) {
		return Math.clamp(puntaje, 0, 100);
	}

	private static double redondear(double valor) {
		return Math.round(valor * 100.0) / 100.0;
	}
}
