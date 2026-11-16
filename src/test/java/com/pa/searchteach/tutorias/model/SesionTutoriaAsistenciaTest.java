package com.pa.searchteach.tutorias.model;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;

class SesionTutoriaAsistenciaTest {

	@Test
	void onlyMarksLateAfterTenMinutesFromTheActualStart() {
		LocalDateTime scheduledStart = LocalDateTime.of(2026, 5, 1, 10, 0);
		LocalDateTime actualStart = scheduledStart.plusMinutes(4);
		SesionTutoria started = session(scheduledStart).iniciar(actualStart);

		AsistenciaEstudiante early = started.registrarEntrada("student", actualStart.plusMinutes(9))
				.asistencias().get(0);
		AsistenciaEstudiante late = started.registrarEntrada("student", actualStart.plusMinutes(10))
				.asistencias().get(0);
		SesionTutoria laterSession = started.registrarEntrada("student", actualStart.plusMinutes(17));
		AsistenciaEstudiante later = laterSession.asistencias().get(0);
		AsistenciaEstudiante reconnect = laterSession
				.registrarEntrada("student", actualStart.plusMinutes(22)).asistencias().get(0);

		assertEquals("PRESENTE", early.estado());
		assertEquals(Integer.valueOf(0), early.minutosTarde());
		assertEquals("ENTRO_TARDE", late.estado());
		assertEquals(Integer.valueOf(10), late.minutosTarde());
		assertEquals(Integer.valueOf(17), later.minutosTarde());
		assertEquals(Integer.valueOf(17), reconnect.minutosTarde());
	}

	private SesionTutoria session(LocalDateTime start) {
		return new SesionTutoria(
				"session",
				"teacher",
				List.of("student"),
				start,
				start.plusHours(1),
				"Desarrollo",
				1,
				List.of(new AsistenciaEstudiante("student", null)),
				"Materia",
				List.of("Desarrollo"),
				ModalidadTutoria.VIRTUAL,
				null);
	}
}
