package com.pa.searchteach.tutorias.modelo;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class TutoriaColectivaTest {

	@Test
	void admiteUnLiderCincoDocentesYUnProyectoPorCadaDocenteDeApoyo() {
		TutoriaColectiva tutoria = tutoriaColectiva();

		assertEquals(5, tutoria.docentesApoyoIds().size());
		assertEquals(5, tutoria.proyectos().size());
		assertEquals(4, tutoria.proyectos().getFirst().estudianteIds().size());
	}

	@Test
	void rechazaProyectosConMenosDeCuatroEstudiantes() {
		assertThrows(IllegalArgumentException.class, () -> new ProyectoAula(
				"proyecto",
				"Proyecto",
				"docente-1",
				List.of("estudiante-1", "estudiante-2", "estudiante-3"),
				"Java",
				4));
	}

	@Test
	void rechazaAsignacionesSiUnDocenteDeApoyoNoTieneProyecto() {
		TutoriaColectiva tutoria = tutoriaColectiva();
		List<ProyectoAula> proyectosSinUnResponsable = tutoria.proyectos().stream()
				.map(proyecto -> new ProyectoAula(
						proyecto.proyectoId(),
						proyecto.nombre(),
						"docente-apoyo-1",
						proyecto.estudianteIds(),
						proyecto.tecnologia(),
						proyecto.semestre()))
				.toList();
		assertThrows(IllegalArgumentException.class, () -> new TutoriaColectiva(
				"tutoria",
				"coordinadora",
				"docente-lider",
				tutoria.docentesApoyoIds(),
				proyectosSinUnResponsable,
				LocalDateTime.now()));
	}

	private TutoriaColectiva tutoriaColectiva() {
		List<String> docentesApoyo = IntStream.rangeClosed(1, 5)
				.mapToObj(index -> "docente-apoyo-" + index)
				.toList();
		List<ProyectoAula> proyectos = IntStream.rangeClosed(1, 5)
				.mapToObj(index -> new ProyectoAula(
						"proyecto-" + index,
						"Proyecto " + index,
						docentesApoyo.get(index - 1),
						IntStream.rangeClosed(1, 4)
								.mapToObj(estudiante -> "estudiante-" + index + "-" + estudiante)
								.toList(),
						"Java",
						4))
				.toList();
		return new TutoriaColectiva(
				"tutoria-1",
				"coordinadora-1",
				"docente-lider",
				docentesApoyo,
				proyectos,
				LocalDateTime.now());
	}
}
