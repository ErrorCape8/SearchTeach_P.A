package com.pa.searchteach.calidad.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.calidad.repository.CalificacionTutoriaRepositorio;
import com.pa.searchteach.tutorias.model.AsistenciaEstudiante;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import org.junit.jupiter.api.Test;

class DirectorCalidadServiceTest {

	@Test
	void filtersQualityByCareerAndSemester() {
		CalificacionTutoriaRepositorio calificacionRepository = mock(CalificacionTutoriaRepositorio.class);
		SesionTutoriaRepositorio sesionRepository = mock(SesionTutoriaRepositorio.class);
		LocalDateTime start = LocalDateTime.of(2026, 5, 1, 10, 0);
		SesionTutoria first = session("first", "Software", 2, start)
				.valorar("student-1", 5, "Buena atención del tutor", start);
		SesionTutoria second = session("second", "Diseño", 4, start.plusDays(1))
				.valorar("student-2", 4, "La clase estuvo bien", start.plusDays(1));
		when(calificacionRepository.findAllByOrderByFechaCreacionDesc()).thenReturn(List.of());
		when(sesionRepository.findAll()).thenReturn(List.of(first, second));

		DirectorCalidadService service =
				new DirectorCalidadService(calificacionRepository, sesionRepository);

		assertEquals(2, service.obtenerResumenCalidad().totalCalificaciones());
		assertEquals(1, service.obtenerResumenCalidad(null, "Software", 2).totalCalificaciones());
		assertEquals(0, service.obtenerResumenCalidad(null, "Software", 4).totalCalificaciones());
	}

	private SesionTutoria session(String id, String career, int semester, LocalDateTime start) {
		return new SesionTutoria(
				id,
				"teacher",
				List.of("student-" + id),
				start,
				start.plusHours(1),
				career,
				semester,
				List.of(new AsistenciaEstudiante("student-" + id, null)),
				"Materia",
				List.of(career),
				ModalidadTutoria.VIRTUAL,
				null);
	}
}
