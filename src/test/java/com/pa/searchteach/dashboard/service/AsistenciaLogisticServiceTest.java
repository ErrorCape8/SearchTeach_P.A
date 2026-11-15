package com.pa.searchteach.dashboard.service;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.time.LocalDateTime;
import java.util.Optional;

import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import org.junit.jupiter.api.Test;

class AsistenciaLogisticServiceTest {

	private static final LocalDateTime LUNES_2_PM = LocalDateTime.of(2026, 11, 9, 14, 0);
	private static final LocalDateTime DOMINGO_2_PM = LocalDateTime.of(2026, 11, 8, 14, 0);

	@Test
	void cargaElModeloYPrediceUnaProbabilidadValida() {
		AsistenciaLogisticService service = new AsistenciaLogisticService();
		service.cargarModelo();

		// Se omite mientras no exista models/asistencia.model.
		assumeTrue(service.isAvailable(), "Falta models/asistencia.model");
		Optional<AsistenciaLogisticService.Prediction> prediction = service.predecir(
				"Programación II", ModalidadTutoria.PRESENCIAL, LUNES_2_PM);

		assertTrue(prediction.isPresent());
		assertTrue(prediction.get().probabilidadAsistencia() >= 0);
		assertTrue(prediction.get().probabilidadAsistencia() <= 1);
	}

	@Test
	void cubreMateriasDelCatalogoYOmiteLasQueNoConoce() {
		AsistenciaLogisticService service = new AsistenciaLogisticService();
		service.cargarModelo();

		assumeTrue(service.isAvailable(), "Falta models/asistencia.model");
		assertTrue(service.predecir("Cálculo diferencial", ModalidadTutoria.HIBRIDA, LUNES_2_PM).isPresent());
		assertTrue(service.predecir("Inglés II", ModalidadTutoria.VIRTUAL, LUNES_2_PM).isPresent());
		assertTrue(service.predecir("Materia desconocida", ModalidadTutoria.VIRTUAL, LUNES_2_PM).isEmpty());
		assertTrue(service.predecir("Programación II", ModalidadTutoria.VIRTUAL, DOMINGO_2_PM).isEmpty());
	}
}
