package com.pa.searchteach.dashboard.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.util.Optional;

import org.junit.jupiter.api.Test;

class PaGruposLogisticServiceTest {

	@Test
	void prediceDistribucionDeGruposNuevos() {
		PaGruposLogisticService service = new PaGruposLogisticService();
		service.cargarModelo();
		assumeTrue(service.isAvailable(), "Falta models/pa_grupos.model");
		Optional<PaGruposLogisticService.Prediction> prediction = service.predecir(
				"Tecnología en Desarrollo de Software", 20, 1, 1.5, 12);
		assertTrue(prediction.isPresent());
		double suma = prediction.get().probabilidades().values().stream().mapToDouble(Double::doubleValue).sum();
		assertEquals(1.0, suma, 1e-6);
	}

	@Test
	void carreraDesconocidaNoSePredice() {
		PaGruposLogisticService service = new PaGruposLogisticService();
		service.cargarModelo();
		assumeTrue(service.isAvailable(), "Falta models/pa_grupos.model");
		assertTrue(service.predecir("Carrera inexistente", 20, 1, 1, 1).isEmpty());
	}
}
