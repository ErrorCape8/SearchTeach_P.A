package com.pa.searchteach.tutorias.servicio;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import com.pa.searchteach.tutorias.dto.PropuestaHorario;
import com.pa.searchteach.tutorias.dto.RegistroAsistencia;
import com.pa.searchteach.tutorias.dto.SolicitudTutoria;
import com.pa.searchteach.tutorias.modelo.EstadoTutoria;
import com.pa.searchteach.tutorias.modelo.ModalidadTutoria;
import com.pa.searchteach.tutorias.modelo.Tutoria;
import com.pa.searchteach.tutorias.repositorio.TutoriaRepositorio;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ServicioTutoriasImplTest {

	private final TutoriaRepositorio repositorio = mock(TutoriaRepositorio.class);
	private final ServicioTutoriasImpl servicio = new ServicioTutoriasImpl(repositorio);

	@Test
	void createsRequestInRequestedStateForAuthenticatedStudent() {
		LocalDateTime inicio = LocalDateTime.of(2026, 10, 8, 10, 0);
		when(repositorio.save(any(Tutoria.class)))
				.thenAnswer(invocation -> invocation.getArgument(0));

		Tutoria tutoria = servicio.solicitar(solicitud(inicio, inicio.plusHours(1)), "student-1");

		assertEquals(EstadoTutoria.SOLICITADA, tutoria.getEstado());
		assertEquals("student-1", tutoria.getEstudianteId());
		assertEquals("teacher-1", tutoria.getDocenteId());
		verify(repositorio).save(tutoria);
	}

	@Test
	void doesNotAllowStudentToCreateRequestForAnotherStudent() {
		LocalDateTime inicio = LocalDateTime.of(2026, 10, 8, 10, 0);

		assertThrows(ResponseStatusException.class,
				() -> servicio.solicitar(solicitud(inicio, inicio.plusHours(1)), "someone-else"));

		verify(repositorio, never()).save(any(Tutoria.class));
	}

	@Test
	void teacherCanProposeAlternativeAndStudentCanConfirmIt() {
		LocalDateTime inicio = LocalDateTime.of(2026, 10, 8, 10, 0);
		Tutoria tutoria = nuevaTutoria("tutoria-1", inicio, EstadoTutoria.SOLICITADA);
		when(repositorio.findById("tutoria-1")).thenReturn(Optional.of(tutoria));
		when(repositorio.findByEstudianteId("student-1")).thenReturn(List.of(tutoria));
		when(repositorio.save(tutoria)).thenReturn(tutoria);

		LocalDateTime alternativa = inicio.plusDays(1);
		Tutoria propuesta = servicio.proponerHorario(
				"tutoria-1", new PropuestaHorario(alternativa, alternativa.plusHours(1)), "teacher-1");
		assertEquals(EstadoTutoria.ALTERNATIVA_PROPUESTA, propuesta.getEstado());

		Tutoria confirmada = servicio.confirmarAlternativa("tutoria-1", "student-1");
		assertEquals(EstadoTutoria.PROGRAMADA, confirmada.getEstado());
		assertEquals(alternativa, confirmada.getFechaInicio());
	}

	@Test
	void rejectsOverlappingProgrammedTutoringWhenAcceptingRequest() {
		LocalDateTime inicio = LocalDateTime.of(2026, 10, 8, 10, 0);
		Tutoria solicitada = nuevaTutoria("requested", inicio, EstadoTutoria.SOLICITADA);
		Tutoria existente = nuevaTutoria(
				"existing", inicio.plusMinutes(30), EstadoTutoria.PROGRAMADA);
		when(repositorio.findById("requested")).thenReturn(Optional.of(solicitada));
		when(repositorio.findByEstudianteId("student-1")).thenReturn(List.of(solicitada, existente));

		assertThrows(ResponseStatusException.class,
				() -> servicio.aceptar("requested", "teacher-1"));

		verify(repositorio, never()).save(solicitada);
	}

	@Test
	void teacherCanFinishTutoringAndRecordAttendance() {
		LocalDateTime inicio = LocalDateTime.of(2026, 10, 8, 10, 0);
		Tutoria tutoria = nuevaTutoria("tutoria-1", inicio, EstadoTutoria.EN_CURSO);
		when(repositorio.findById("tutoria-1")).thenReturn(Optional.of(tutoria));
		when(repositorio.save(tutoria)).thenReturn(tutoria);

		Tutoria finalizada = servicio.finalizar(
				"tutoria-1", new RegistroAsistencia(true), "teacher-1");

		assertEquals(EstadoTutoria.REALIZADA, finalizada.getEstado());
		assertEquals(true, finalizada.getAsistio());
	}

	private SolicitudTutoria solicitud(LocalDateTime inicio, LocalDateTime fin) {
		return new SolicitudTutoria(
				"student-1", "teacher-1", "Matemáticas", ModalidadTutoria.VIRTUAL, inicio, fin);
	}

	private Tutoria nuevaTutoria(String id, LocalDateTime inicio, EstadoTutoria estado) {
		Tutoria tutoria = new Tutoria();
		tutoria.setId(id);
		tutoria.setEstudianteId("student-1");
		tutoria.setDocenteId("teacher-1");
		tutoria.setFechaInicio(inicio);
		tutoria.setFechaFin(inicio.plusHours(1));
		tutoria.setEstado(estado);
		return tutoria;
	}
}
