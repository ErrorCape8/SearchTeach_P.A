package com.pa.searchteach.tutorias.modelo;

import java.time.LocalDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SesionTutoriaTest {

	private final LocalDateTime inicio = LocalDateTime.of(2026, 10, 13, 9, 0);

	@Test
	void creaLaSesionConAsistenciaSinMarcarPorCadaEstudiante() {
		SesionTutoria sesion = crearSesion(List.of("est-1", "est-2"));

		assertEquals("doc-1", sesion.docenteId());
		assertEquals("Java", sesion.tecnologia());
		assertEquals(4, sesion.semestre());
		assertEquals(2, sesion.asistencias().size());
		assertNull(sesion.asistencias().get(0).asistio());
		assertNull(sesion.asistencias().get(1).asistio());
	}

	@Test
	void permiteRegistrarAsistenciaIndividualSinAlterarLosDemasEstudiantes() {
		SesionTutoria sesion = crearSesion(List.of("est-1", "est-2"))
				.registrarAsistencia("est-1", true)
				.registrarAsistencia("est-2", false);

		assertTrue(sesion.asistencias().get(0).asistio());
		assertFalse(sesion.asistencias().get(1).asistio());
	}

	@Test
	void impideAgregarMasDeCincoEstudiantes() {
		assertThrows(IllegalArgumentException.class, () -> crearSesion(
				List.of("est-1", "est-2", "est-3", "est-4", "est-5", "est-6")));
	}

	@Test
	void impideRegistrarAsistenciaDeUnEstudianteAjenoALaSesion() {
		assertThrows(
				IllegalArgumentException.class,
				() -> crearSesion(List.of("est-1")).registrarAsistencia("est-2", true));
	}

	@Test
	void exigeFechaFinalPosteriorALaInicial() {
		assertThrows(
				IllegalArgumentException.class,
				() -> SesionTutoria.crear(
						"doc-1",
						List.of("est-1"),
						inicio,
						inicio,
						"Java",
						4));
	}

	private SesionTutoria crearSesion(List<String> estudiantes) {
		return SesionTutoria.crear(
				"doc-1",
				estudiantes,
				inicio,
				inicio.plusHours(1),
				"Java",
				4);
	}
}
