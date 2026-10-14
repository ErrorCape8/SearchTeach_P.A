package com.pa.searchteach.tutorias.servicio;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import com.pa.searchteach.tutorias.modelo.HorarioTutor;
import com.pa.searchteach.tutorias.repositorio.HorarioTutorRepository;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class HorariosTutoresServiceTest {

	private HorarioTutorRepository horarios;
	private UserRepository usuarios;
	private HorariosTutoresService service;

	@BeforeEach
	void setUp() {
		horarios = mock(HorarioTutorRepository.class);
		usuarios = mock(UserRepository.class);
		service = new HorariosTutoresService(horarios, usuarios);
	}

	@Test
	void listaDisponibilidadSinDuplicarUsuariosQueTambienSonEstudiantes() {
		User docente = new User(
				"docente-1", null, "Ana Docente", "ana@example.edu", null,
				"Docente y Estudiante", "Activo");
		User estudiante = new User(
				"estudiante-1", null, "Luis Estudiante", "luis@example.edu", null,
				"Estudiante", "Activo");
		HorarioTutor horario = new HorarioTutor(
				"horario-1", "docente-1", "Ingeniería", 4, "Jueves",
				"14:00", "15:00", "Virtual", "", LocalDateTime.now());
		when(usuarios.findAll()).thenReturn(List.of(docente, estudiante));
		when(horarios.findAllByOrderByActualizadoEnDesc()).thenReturn(List.of(horario));

		var disponibles = service.listarDisponibles();

		assertThat(disponibles).hasSize(1);
		assertThat(disponibles.getFirst().docenteId()).isEqualTo("docente-1");
		assertThat(disponibles.getFirst().nombre()).isEqualTo("Ana Docente");
		assertThat(disponibles.getFirst().carrera()).isEqualTo("Ingeniería");
	}

	@Test
	void aceptaUnaTutoriaFuturaQueCoincideConElHorarioPublicado() {
		User docente = new User(
				"docente-1", null, "Ana Docente", "ana@example.edu", null,
				"Docente y Estudiante", "Activo");
		HorarioTutor horario = new HorarioTutor(
				"horario-1", "docente-1", "Ingeniería", 4, "Lunes",
				"14:00", "15:00", "Híbrida", "Aula 2", LocalDateTime.now());
		when(usuarios.findById("docente-1")).thenReturn(Optional.of(docente));
		when(horarios.findByDocenteId("docente-1")).thenReturn(Optional.of(horario));

		service.validarDisponibilidad(
				"docente-1",
				"HIBRIDA",
				LocalDateTime.of(2099, 1, 5, 14, 0),
				LocalDateTime.of(2099, 1, 5, 15, 0));
	}

	@Test
	void rechazaSolicitudesFueraDelHorarioPublicado() {
		User docente = new User(
				"docente-1", null, "Ana Docente", "ana@example.edu", null,
				"Docente", "Activo");
		HorarioTutor horario = new HorarioTutor(
				"horario-1", "docente-1", "Ingeniería", 4, "Lunes",
				"14:00", "15:00", "Híbrida", "Aula 2", LocalDateTime.now());
		when(usuarios.findById("docente-1")).thenReturn(Optional.of(docente));
		when(horarios.findByDocenteId("docente-1")).thenReturn(Optional.of(horario));

		assertThatThrownBy(() -> service.validarDisponibilidad(
				"docente-1",
				"HIBRIDA",
				LocalDateTime.of(2099, 1, 5, 16, 0),
				LocalDateTime.of(2099, 1, 5, 17, 0)))
				.isInstanceOf(ResponseStatusException.class)
				.hasMessageContaining("no coincide con el horario publicado");
	}
}
