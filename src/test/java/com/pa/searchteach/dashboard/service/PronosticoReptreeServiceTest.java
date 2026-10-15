package com.pa.searchteach.dashboard.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import com.pa.searchteach.dashboard.dto.PronosticoDemanda;
import com.pa.searchteach.dashboard.dto.WeeklyTutoringCount;
import org.junit.jupiter.api.Test;
import org.springframework.data.mongodb.core.MongoTemplate;

class PronosticoReptreeServiceTest {

	@Test
	void cargaElModeloYPrediceUnValorDentroDelRangoEsperado() throws Exception {
		PronosticoReptreeService service = new PronosticoReptreeService();
		service.cargarModelo();

		assertTrue(service.isAvailable());
		Optional<List<Long>> predictions = service.pronosticar(
				"Algebra Lineal",
				historial(),
				LocalDate.of(2026, 10, 19));

		assertTrue(predictions.isPresent());
		assertTrue(predictions.get().getFirst() >= 0);
		assertTrue(predictions.get().getFirst() <= 30);
	}

	@Test
	void usaLaRegresionCuandoReptreeNoEstaDisponible() throws Exception {
		PronosticoReptreeService reptreeService = mock(PronosticoReptreeService.class);
		when(reptreeService.pronosticar(
				"Algebra Lineal", historial(), LocalDate.of(2026, 10, 19)))
				.thenReturn(Optional.empty());
		DirectorDashboardService dashboardService = new DirectorDashboardService(
				mock(MongoTemplate.class), reptreeService);
		List<WeeklyTutoringCount> historial = historial();

		PronosticoDemanda actual = dashboardService.pronosticarMateria(
				"Algebra Lineal", historial, LocalDate.of(2026, 10, 19));
		PronosticoDemanda expected = RegresionDemandaSemanal.pronosticar(historial);

		assertEquals(expected, actual);
		assertEquals("REGRESION", actual.modelo());
	}

	private static List<WeeklyTutoringCount> historial() {
		LocalDate start = LocalDate.of(2026, 9, 21);
		return List.of(
				new WeeklyTutoringCount(start, 3),
				new WeeklyTutoringCount(start.plusWeeks(1), 5),
				new WeeklyTutoringCount(start.plusWeeks(2), 4),
				new WeeklyTutoringCount(start.plusWeeks(3), 6));
	}
}
