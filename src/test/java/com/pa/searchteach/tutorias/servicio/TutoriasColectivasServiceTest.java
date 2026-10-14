package com.pa.searchteach.tutorias.servicio;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.IntStream;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.tutorias.dto.InformeAvanceSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.modelo.ProyectoAula;
import com.pa.searchteach.tutorias.modelo.TutoriaColectiva;
import com.pa.searchteach.tutorias.repositorio.InformeAvanceProyectoRepositorio;
import com.pa.searchteach.tutorias.repositorio.TutoriaColectivaRepositorio;
import com.pa.searchteach.users.repository.UserRepository;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class TutoriasColectivasServiceTest {

	private final TutoriaColectivaRepositorio tutorias = mock(TutoriaColectivaRepositorio.class);
	private final InformeAvanceProyectoRepositorio informes = mock(InformeAvanceProyectoRepositorio.class);
	private final UserRepository usuarios = mock(UserRepository.class);
	private final TutoriasColectivasService servicio =
			new TutoriasColectivasService(tutorias, informes, usuarios);

	@Test
	void creaGrupoConCincoProyectosYAsignaUnResponsablePorProyecto() {
		when(usuarios.existsById(anyString())).thenReturn(true);
		when(tutorias.save(any())).thenAnswer(invocation -> invocation.getArgument(0));

		var created = servicio.crear(solicitudCreacion(), "coordinadora");

		assertEquals(5, created.proyectos().size());
		assertEquals(created.docentesApoyoIds(),
				created.proyectos().stream().map(ProyectoAula::docenteResponsableId).toList());
		verify(tutorias).save(any());
	}

	@Test
	void rechazaDocentesQueNoTienenCuentaRegistrada() {
		when(usuarios.existsById(anyString())).thenReturn(true);
		when(usuarios.existsById("docente-apoyo-5")).thenReturn(false);

		assertThrows(
				IllegalArgumentException.class,
				() -> servicio.crear(solicitudCreacion(), "coordinadora"));

		verify(tutorias, never()).save(any());
	}

	@Test
	void soloElDocenteDeApoyoAsignadoPuedeInformarSobreSuProyecto() {
		when(tutorias.findById("tutoria-1")).thenReturn(Optional.of(tutoriaColectiva()));

		assertThrows(
				ForbiddenException.class,
				() -> servicio.registrarInforme(
						"tutoria-1",
						"proyecto-1",
						new InformeAvanceSolicitud(75, "Avance"),
						"docente-ajeno"));

		verify(informes, never()).save(any());
	}

	private TutoriaColectivaSolicitud solicitudCreacion() {
		List<String> apoyos = IntStream.rangeClosed(1, 5)
				.mapToObj(index -> "docente-apoyo-" + index)
				.toList();
		List<ProyectoAulaSolicitud> proyectos = IntStream.rangeClosed(1, 5)
				.mapToObj(index -> new ProyectoAulaSolicitud(
						"Proyecto " + index,
						apoyos.get(index - 1),
						IntStream.rangeClosed(1, 4)
								.mapToObj(estudiante -> "estudiante-" + index + "-" + estudiante)
								.toList(),
						"Java",
						4))
				.toList();
		return new TutoriaColectivaSolicitud("docente-lider", apoyos, proyectos);
	}

	@Test
	void rechazaUnProyectoQueNoPerteneceATutoriaColectiva() {
		when(tutorias.findById("tutoria-1")).thenReturn(Optional.of(tutoriaColectiva()));

		assertThrows(
				com.pa.searchteach.common.exception.NotFoundException.class,
				() -> servicio.registrarInforme(
						"tutoria-1",
						"proyecto-ajeno",
						new InformeAvanceSolicitud(75, "Avance"),
						"docente-apoyo-1"));

		verify(informes, never()).save(any());
	}

	private TutoriaColectiva tutoriaColectiva() {
		List<String> apoyos = IntStream.rangeClosed(1, 5)
				.mapToObj(index -> "docente-apoyo-" + index)
				.toList();
		List<ProyectoAula> proyectos = IntStream.rangeClosed(1, 5)
				.mapToObj(index -> new ProyectoAula(
						"proyecto-" + index,
						"Proyecto " + index,
						apoyos.get(index - 1),
						IntStream.rangeClosed(1, 4)
								.mapToObj(estudiante -> "estudiante-" + index + "-" + estudiante)
								.toList(),
						"Java",
						4))
				.toList();
		return new TutoriaColectiva(
				"tutoria-1",
				"coordinadora",
				"docente-lider",
				apoyos,
				proyectos,
				LocalDateTime.of(2026, 10, 13, 9, 0));
	}
}
