package com.pa.searchteach.tutorias.servicio;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Locale;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Set;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.tutorias.dto.DocenteCoordinacion;
import com.pa.searchteach.tutorias.dto.HorarioTutorSolicitud;
import com.pa.searchteach.tutorias.dto.TutorDisponible;
import com.pa.searchteach.tutorias.modelo.HorarioTutor;
import com.pa.searchteach.tutorias.modelo.MateriaHorario;
import com.pa.searchteach.tutorias.modelo.CatalogoTecnologias;
import com.pa.searchteach.tutorias.repositorio.HorarioTutorRepository;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class HorariosTutoresService {

	private static final List<String> DIAS = List.of(
			"Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo");
	private static final List<String> MODALIDADES = List.of("Presencial", "Virtual", "Híbrida");

	private final HorarioTutorRepository horarios;
	private final UserRepository usuarios;

	public HorariosTutoresService(HorarioTutorRepository horarios, UserRepository usuarios) {
		this.horarios = horarios;
		this.usuarios = usuarios;
	}

	public List<DocenteCoordinacion> listarDocentes() {
		return usuarios.findAll().stream()
				.filter(this::esDocente)
				.filter(user -> user.getEstado() == null || user.getEstado().isBlank()
						|| "Activo".equalsIgnoreCase(user.getEstado()))
				.map(user -> new DocenteCoordinacion(user.getId(), valor(user.getNombre())))
				.toList();
	}

	public List<HorarioTutor> listarHorarios() {
		return horarios.findAllByOrderByActualizadoEnDesc();
	}

	public List<TutorDisponible> listarDisponibles() {
		var nombres = listarDocentes().stream()
				.collect(java.util.stream.Collectors.toMap(
						DocenteCoordinacion::id, DocenteCoordinacion::nombre));
		return listarHorarios().stream()
				.filter(horario -> nombres.containsKey(horario.docenteId()))
				.map(horario -> new TutorDisponible(
						horario.docenteId(),
						nombres.get(horario.docenteId()),
						horario.carrera(),
						horario.semestre(),
						horario.dia(),
						horario.horaInicio(),
						horario.horaFin(),
						horario.modalidad(),
						horario.ubicacion(),
						carrerasDe(horario),
						horario.materias()))
				.toList();
	}

	public void validarDisponibilidad(
			String docenteId,
			String modalidad,
			LocalDateTime fechaInicio,
			LocalDateTime fechaFin) {
		User docente = obtenerDocente(docenteId);
		if (docente.getEstado() != null && !docente.getEstado().isBlank()
				&& !"Activo".equalsIgnoreCase(docente.getEstado())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El docente seleccionado no está activo.");
		}
		HorarioTutor horario = horarios.findByDocenteId(docenteId)
				.orElseThrow(() -> new NotFoundException(
						"El docente seleccionado no tiene horarios disponibles."));
		if (fechaInicio == null || fechaFin == null || !fechaFin.isAfter(fechaInicio)
				|| !fechaInicio.toLocalDate().equals(fechaFin.toLocalDate())
				|| !fechaInicio.isAfter(LocalDateTime.now())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Selecciona una fecha futura y un rango horario válido.");
		}
		String diaSolicitado = DIAS.get(fechaInicio.getDayOfWeek().getValue() - 1);
		LocalTime inicioDisponible = LocalTime.parse(horario.horaInicio());
		LocalTime finDisponible = LocalTime.parse(horario.horaFin());
		if (!horario.dia().equals(diaSolicitado)
				|| !modalidadNormalizada(horario.modalidad()).equals(modalidad)
				|| fechaInicio.toLocalTime().isBefore(inicioDisponible)
				|| fechaFin.toLocalTime().isAfter(finDisponible)) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La fecha o modalidad no coincide con el horario publicado por el docente.");
		}
	}

	public void validarMateria(String docenteId, String estudianteId, String materia) {
		HorarioTutor horario = horarios.findByDocenteId(docenteId)
				.orElseThrow(() -> new NotFoundException("El docente seleccionado no tiene horarios disponibles."));
		if (horario.materias().isEmpty()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El docente aún no tiene materias preconfiguradas para sus tutorías.");
		}

		User estudiante = usuarios.findById(estudianteId)
				.orElseThrow(() -> new NotFoundException("No se encontrÃ³ el estudiante seleccionado."));
		String carrera = valor(estudiante.getCarrera());
		boolean disponible = horario.materias().stream()
				.filter(item -> item.nombre().equalsIgnoreCase(valor(materia)))
				.anyMatch(item -> item.carreras().stream().anyMatch(c -> c.equalsIgnoreCase(carrera)));
		if (!disponible) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La materia no estÃ¡ disponible para la tecnologÃ­a del estudiante.");
		}
	}

	public HorarioTutor crear(String docenteId, HorarioTutorSolicitud solicitud) {
		User docente = obtenerDocente(docenteId);
		if (horarios.findByDocenteId(docenteId).isPresent()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "El docente ya tiene un horario asignado.");
		}
		return horarios.save(construir(null, docente.getId(), solicitud));
	}

	public HorarioTutor actualizar(String docenteId, HorarioTutorSolicitud solicitud) {
		obtenerDocente(docenteId);
		HorarioTutor actual = horarios.findByDocenteId(docenteId)
				.orElseThrow(() -> new NotFoundException("El docente todavía no tiene un horario asignado."));
		return horarios.save(construir(actual.id(), docenteId, solicitud));
	}

	public void eliminar(String docenteId) {
		if (horarios.findByDocenteId(docenteId).isEmpty()) {
			throw new NotFoundException("El docente todavía no tiene un horario asignado.");
		}
		horarios.deleteByDocenteId(docenteId);
	}

	private HorarioTutor construir(String id, String docenteId, HorarioTutorSolicitud solicitud) {
		if (!CatalogoTecnologias.contiene(solicitud.carrera())) {
			throw new IllegalArgumentException("Selecciona una tecnología del catálogo institucional.");
		}
		if (!DIAS.contains(solicitud.dia())) {
			throw new IllegalArgumentException("Selecciona un día válido.");
		}
		if (!MODALIDADES.contains(solicitud.modalidad())) {
			throw new IllegalArgumentException("Selecciona una modalidad válida.");
		}
		if (!LocalTime.parse(solicitud.horaFin()).isAfter(LocalTime.parse(solicitud.horaInicio()))) {
			throw new IllegalArgumentException("La hora de finalización debe ser posterior a la de inicio.");
		}
		if (!"Virtual".equals(solicitud.modalidad())
				&& (solicitud.ubicacion() == null || solicitud.ubicacion().isBlank())) {
			throw new IllegalArgumentException("Indica la ubicación para las sesiones presenciales.");
		}
		List<MateriaHorario> materias = solicitud.materias() == null ? List.of() : solicitud.materias();
		if (materias.size() > 2) {
			throw new IllegalArgumentException("Cada docente puede tener como máximo dos materias asignadas.");
		}
		Set<String> nombresMateria = new HashSet<>();
		for (MateriaHorario materia : materias) {
			if (materia == null || materia.nombre() == null || materia.nombre().isBlank()
					|| materia.carreras() == null || materia.carreras().isEmpty()
					|| materia.carreras().stream().anyMatch(carrera -> !CatalogoTecnologias.contiene(carrera))
					|| materia.carreras().stream().noneMatch(carrera -> carrera.equalsIgnoreCase(solicitud.carrera().trim()))
					|| !nombresMateria.add(materia.nombre().trim().toLowerCase(Locale.ROOT))) {
				throw new IllegalArgumentException("Cada materia debe ser única y estar asociada a la tecnología del horario.");
			}
		}
		return new HorarioTutor(
				id,
				docenteId,
				solicitud.carrera().trim(),
				solicitud.semestre(),
				solicitud.dia(),
				solicitud.horaInicio(),
				solicitud.horaFin(),
				solicitud.modalidad(),
				valor(solicitud.ubicacion()),
				LocalDateTime.now(),
				materias);
	}

	private List<String> carrerasDe(HorarioTutor horario) {
		List<String> carreras = new ArrayList<>();
		carreras.add(horario.carrera());
		horario.materias().forEach(materia -> carreras.addAll(materia.carreras()));
		return carreras.stream().distinct().toList();
	}

	private User obtenerDocente(String docenteId) {
		User docente = usuarios.findById(docenteId)
				.orElseThrow(() -> new NotFoundException("No se encontró el docente seleccionado."));
		if (!esDocente(docente)) {
			throw new IllegalArgumentException("El usuario seleccionado no tiene rol de docente.");
		}
		return docente;
	}

	private boolean esDocente(User user) {
		return user.getRol() != null
				&& user.getRol().toLowerCase(Locale.ROOT).contains("docente");
	}

	private String modalidadNormalizada(String modalidad) {
		return modalidad.toUpperCase(Locale.ROOT).replace("Í", "I");
	}

	private String valor(String value) {
		return value == null ? "" : value.trim();
	}
}
