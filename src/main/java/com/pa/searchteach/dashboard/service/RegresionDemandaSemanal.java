package com.pa.searchteach.dashboard.service;

import java.util.List;

import com.pa.searchteach.dashboard.dto.PronosticoDemanda;
import com.pa.searchteach.dashboard.dto.WeeklyTutoringCount;

final class RegresionDemandaSemanal {

	private static final double UMBRAL_TENDENCIA_ESTABLE = 0.10;
	private static final double[] T_95 = {
			Double.NaN, Double.NaN, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306
	};

	private RegresionDemandaSemanal() {
	}

	static PronosticoDemanda pronosticar(List<WeeklyTutoringCount> historial) {
		int cantidad = historial.size();
		if (cantidad < 4 || cantidad > 10) {
			throw new IllegalArgumentException("El modelo requiere entre 4 y 10 semanas completas.");
		}

		double promedioX = (cantidad - 1) / 2.0;
		double promedioY = historial.stream().mapToLong(WeeklyTutoringCount::total).average().orElse(0);
		double sumaXX = 0;
		double sumaXY = 0;
		for (int indice = 0; indice < cantidad; indice++) {
			double x = indice - promedioX;
			double y = historial.get(indice).total() - promedioY;
			sumaXX += x * x;
			sumaXY += x * y;
		}

		double pendiente = sumaXY / sumaXX;
		double intercepto = promedioY - pendiente * promedioX;
		double residuosCuadrados = 0;
		for (int indice = 0; indice < cantidad; indice++) {
			double residuo = historial.get(indice).total() - (intercepto + pendiente * indice);
			residuosCuadrados += residuo * residuo;
		}
		double varianzaResidual = residuosCuadrados / (cantidad - 2);
		int gradosLibertad = cantidad - 2;
		double valorCritico = gradosLibertad < T_95.length
				? T_95[gradosLibertad]
				: 1.96;

		RangoPronostico proximaSemana = calcularRango(
				intercepto, pendiente, varianzaResidual, promedioX, sumaXX, cantidad, 1, valorCritico);
		RangoPronostico proximasCuatroSemanas = calcularRango(
				intercepto, pendiente, varianzaResidual, promedioX, sumaXX, cantidad, 4, valorCritico);

		double promedioReciente = historial.subList(cantidad - 4, cantidad).stream()
				.mapToLong(WeeklyTutoringCount::total)
				.average()
				.orElse(0);
		double cambio = proximaSemana.estimado() - promedioReciente;
		double umbralEstable = Math.max(1, promedioReciente * UMBRAL_TENDENCIA_ESTABLE);
		String tendencia = cambio > umbralEstable ? "SUBE"
				: cambio < -umbralEstable ? "BAJA" : "ESTABLE";

		return new PronosticoDemanda(
				List.copyOf(historial),
				proximaSemana.estimado(),
				proximaSemana.minimo(),
				proximaSemana.maximo(),
				proximasCuatroSemanas.estimado(),
				proximasCuatroSemanas.minimo(),
				proximasCuatroSemanas.maximo(),
				tendencia,
				"SUBE".equals(tendencia));
	}

	private static RangoPronostico calcularRango(
			double intercepto,
			double pendiente,
			double varianzaResidual,
			double promedioX,
			double sumaXX,
			int cantidadMuestras,
			int horizonte,
			double valorCritico) {
		double estimado = 0;
		double desplazamientoFuturo = 0;
		for (int paso = 0; paso < horizonte; paso++) {
			double xFuturo = cantidadMuestras + paso;
			estimado += intercepto + pendiente * xFuturo;
			desplazamientoFuturo += xFuturo - promedioX;
		}

		long estimadoRedondeado = Math.max(0, Math.round(estimado));
		double factorVarianza = horizonte
				+ (double) horizonte * horizonte / cantidadMuestras
				+ desplazamientoFuturo * desplazamientoFuturo / sumaXX;
		double margen = valorCritico * Math.sqrt(varianzaResidual * factorVarianza);
		long minimo = Math.max(0, (long) Math.floor(estimado - margen));
		long maximo = Math.max(estimadoRedondeado, (long) Math.ceil(estimado + margen));
		return new RangoPronostico(estimadoRedondeado, minimo, maximo);
	}

	private record RangoPronostico(long estimado, long minimo, long maximo) {
	}
}
