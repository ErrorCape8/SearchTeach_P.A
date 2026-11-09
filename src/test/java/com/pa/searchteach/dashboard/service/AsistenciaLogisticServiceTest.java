package com.pa.searchteach.dashboard.service;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDateTime;
import java.util.Optional;

import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.Tutoria;
import org.junit.jupiter.api.Test;

class AsistenciaLogisticServiceTest {

	@Test
	void cargaElModeloYPrediceUnaProbabilidadValida() throws Exception {
		AsistenciaLogisticService service = new AsistenciaLogisticService();
		service.cargarModelo();

		assertTrue(service.isAvailable());
		Optional<AsistenciaLogisticService.Prediction> prediction = service.predecir(
				tutoria(ModalidadTutoria.PRESENCIAL, "Bases de Datos"));

		assertTrue(prediction.isPresent());
		assertTrue(prediction.get().probabilidadAsistencia() >= 0);
		assertTrue(prediction.get().probabilidadAsistencia() <= 1);
	}

	@Test
	void omiteCategoriasQueElModeloNoConoce() throws Exception {
		AsistenciaLogisticService service = new AsistenciaLogisticService();
		service.cargarModelo();

		assertTrue(service.predecir(tutoria(ModalidadTutoria.HIBRIDA, "Bases de Datos")).isEmpty());
		assertTrue(service.predecir(tutoria(ModalidadTutoria.VIRTUAL, "Materia desconocida")).isEmpty());
	}

	private static Tutoria tutoria(ModalidadTutoria modalidad, String materia) {
		Tutoria tutoria = new Tutoria();
		tutoria.setMateria(materia);
		tutoria.setModalidad(modalidad);
		tutoria.setFechaInicio(LocalDateTime.of(2026, 11, 9, 14, 0));
		return tutoria;
	}
}
