package com.pa.searchteach.dashboard.service;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.IntStream;

import com.pa.searchteach.dashboard.dto.WeeklyTutoringCount;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class RegresionDemandaSemanalTest {

	@Test
	void pronosticaLaProximaSemanaYLasSiguientesCuatroConUnaTendenciaCreciente() {
		var pronostico = RegresionDemandaSemanal.pronosticar(historial(1, 2, 3, 4, 5, 6, 7, 8, 9, 10));

		assertEquals(11, pronostico.estimadoProximaSemana());
		assertEquals(50, pronostico.estimadoProximasCuatroSemanas());
		assertEquals("SUBE", pronostico.tendencia());
		assertTrue(pronostico.alertaCreciente());
		assertTrue(pronostico.minimoProximaSemana() <= pronostico.estimadoProximaSemana());
		assertTrue(pronostico.maximoProximaSemana() >= pronostico.estimadoProximaSemana());
	}

	@Test
	void clasificaLaDemandaConstanteComoEstable() {
		var pronostico = RegresionDemandaSemanal.pronosticar(historial(3, 3, 3, 3, 3, 3));

		assertEquals(3, pronostico.estimadoProximaSemana());
		assertEquals("ESTABLE", pronostico.tendencia());
		assertFalse(pronostico.alertaCreciente());
		assertEquals(6, pronostico.historialSolicitudes().size());
	}

	@Test
	void calculaUnRangoPredictivoParaLaSumaDeLasProximasCuatroSemanas() {
		var pronostico = RegresionDemandaSemanal.pronosticar(historial(2, 5, 3, 8, 4, 9));

		assertTrue(pronostico.minimoProximasCuatroSemanas()
				< pronostico.estimadoProximasCuatroSemanas());
		assertTrue(pronostico.maximoProximasCuatroSemanas()
				> pronostico.estimadoProximasCuatroSemanas());
		assertTrue(pronostico.maximoProximasCuatroSemanas()
				- pronostico.minimoProximasCuatroSemanas()
				> pronostico.maximoProximaSemana() - pronostico.minimoProximaSemana());
	}

	@Test
	void limitaAZeroLosPronosticosDeUnaTendenciaDecreciente() {
		var pronostico = RegresionDemandaSemanal.pronosticar(historial(10, 9, 8, 7, 6, 5, 4, 3, 2, 1));

		assertEquals(0, pronostico.estimadoProximaSemana());
		assertEquals(0, pronostico.minimoProximaSemana());
		assertEquals("BAJA", pronostico.tendencia());
		assertFalse(pronostico.alertaCreciente());
	}

	@Test
	void exigeAlMenosCuatroSemanasDeHistorial() {
		assertThrows(
				IllegalArgumentException.class,
				() -> RegresionDemandaSemanal.pronosticar(historial(4, 3, 2)));
	}

	private List<WeeklyTutoringCount> historial(long... totals) {
		LocalDate monday = LocalDate.of(2026, 1, 5);
		return IntStream.range(0, totals.length)
				.mapToObj(index -> new WeeklyTutoringCount(monday.plusWeeks(index), totals[index]))
				.toList();
	}
}
