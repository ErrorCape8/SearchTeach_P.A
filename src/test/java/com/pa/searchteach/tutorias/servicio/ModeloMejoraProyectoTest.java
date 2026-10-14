package com.pa.searchteach.tutorias.servicio;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.tutorias.modelo.InformeAvanceProyecto;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

class ModeloMejoraProyectoTest {

	@Test
	void pronosticaMejoraConPuntajesDeAvanceCrecientes() {
		var resultado = ModeloMejoraProyecto.evaluar(List.of(
				informe(40, 1),
				informe(50, 2),
				informe(60, 3)));

		assertEquals("MEJORA_PRONOSTICADA", resultado.tendencia());
		assertEquals(100.0, resultado.puntajePronosticadoEnCuatroSemanas());
		assertEquals(40.0, resultado.cambioPronosticado());
	}

	@Test
	void pronosticaRetrocesoConPuntajesDeAvanceDecrecientes() {
		var resultado = ModeloMejoraProyecto.evaluar(List.of(
				informe(80, 1),
				informe(60, 2),
				informe(40, 3)));

		assertEquals("RETROCESO_PRONOSTICADO", resultado.tendencia());
		assertEquals(0.0, resultado.puntajePronosticadoEnCuatroSemanas());
	}

	@Test
	void indicaInsuficienciaSinTresFechasDeInforme() {
		var resultado = ModeloMejoraProyecto.evaluar(List.of(informe(40, 1), informe(60, 2)));

		assertEquals("DATOS_INSUFICIENTES", resultado.tendencia());
		assertEquals(60.0, resultado.puntajeActual());
		assertNull(resultado.puntajePronosticadoEnCuatroSemanas());
	}

	@Test
	void agrupaInformesDelMismoDiaEnUnaSolaMedicion() {
		var resultado = ModeloMejoraProyecto.evaluar(List.of(
				informe(40, 1),
				informe(60, 1),
				informe(50, 2),
				informe(50, 3)));

		assertEquals("ESTABLE", resultado.tendencia());
		assertEquals(4, resultado.informesEvaluados());
	}

	private InformeAvanceProyecto informe(int puntaje, int semana) {
		return new InformeAvanceProyecto(
				"inf-" + semana + "-" + puntaje,
				"tutoria-1",
				"proyecto-1",
				"docente-1",
				puntaje,
				"Avance semanal",
				LocalDateTime.of(2026, 1, 5, 9, 0).plusWeeks(semana));
	}
}
