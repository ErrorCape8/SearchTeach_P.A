package com.pa.searchteach.dashboard.service;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDateTime;
import java.util.Optional;

import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import org.junit.jupiter.api.Test;

class AsistenciaLogisticServiceTest {

	private static final LocalDateTime LUNES_2_PM = LocalDateTime.of(2026, 11, 9, 14, 0);

	@Test
	void cargaElModeloYPrediceUnaProbabilidadValida() {
		AsistenciaLogisticService service = new AsistenciaLogisticService();
		service.cargarModelo();

		assertTrue(service.isAvailable());
		Optional<AsistenciaLogisticService.Prediction> prediction = service.predecir(
				"Bases de Datos", ModalidadTutoria.PRESENCIAL, LUNES_2_PM);

		assertTrue(prediction.isPresent());
		assertTrue(prediction.get().probabilidadAsistencia() >= 0);
		assertTrue(prediction.get().probabilidadAsistencia() <= 1);
	}

	@Test
	void omiteCategoriasQueElModeloNoConoce() {
		AsistenciaLogisticService service = new AsistenciaLogisticService();
		service.cargarModelo();

		assertTrue(service.predecir("Bases de Datos", ModalidadTutoria.HIBRIDA, LUNES_2_PM).isEmpty());
		assertTrue(service.predecir("Materia desconocida", ModalidadTutoria.VIRTUAL, LUNES_2_PM).isEmpty());
	}
}
