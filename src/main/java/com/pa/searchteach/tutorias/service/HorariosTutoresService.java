package com.pa.searchteach.tutorias.service;

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
import com.pa.searchteach.tutorias.model.HorarioTutor;
import com.pa.searchteach.tutorias.model.CatalogoMateriasTecnologia;
import com.pa.searchteach.tutorias.model.MateriaHorario;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import com.pa.searchteach.tutorias.repository.HorarioTutorRepository;
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

	public List<MateriaHorario> listarMaterias(String tecnologia, int semestre) {
		return CatalogoMateriasTecnologia.listar(tecnologia, semestre);
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
						materiasCompartidas(horario)))
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
		boolean disponible = materiasCompartidas(horario).stream()
				.filter(item -> CatalogoMateriasTecnologia.normalizar(item.nombre())
						.equals(CatalogoMateriasTecnologia.normalizar(materia)))
				.anyMatch(item -> item.carreras().stream()
						.anyMatch(c -> CatalogoMateriasTecnologia.normalizar(c)
								.equals(CatalogoMateriasTecnologia.normalizar(carrera))));
		if (!disponible) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La materia no estÃ¡ disponible para la tecnologÃ­a del estudiante.");
		}
	}

	public void validarMateriaParaTecnologia(
			String docenteId, String tecnologia, int semestre, String materia) {
		HorarioTutor horario = horarios.findByDocenteId(docenteId)
				.orElseThrow(() -> new NotFoundException("El docente seleccionado no tiene horarios disponibles."));
		if (horario.semestre() != semestre) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El semestre no coincide con el horario del docente.");
		}
		boolean disponible = materiasCompartidas(horario).stream()
				.filter(item -> CatalogoMateriasTecnologia.normalizar(item.nombre())
						.equals(CatalogoMateriasTecnologia.normalizar(materia)))
				.anyMatch(item -> item.carreras().stream()
						.anyMatch(c -> CatalogoMateriasTecnologia.normalizar(c)
								.equals(CatalogoMateriasTecnologia.normalizar(tecnologia))));
		if (!disponible) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El docente no tiene asignada esa materia para la tecnología seleccionada.");
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
		if (solicitud.semestre() < 1 || solicitud.semestre() > 6) {
			throw new IllegalArgumentException("El semestre debe estar entre 1 y 6.");
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
		List<MateriaHorario> materiasCatalogo = new ArrayList<>();
		for (MateriaHorario materia : materias) {
			if (materia == null || materia.nombre() == null || materia.nombre().isBlank()
					|| !CatalogoMateriasTecnologia.contiene(
							solicitud.carrera(), solicitud.semestre(), materia.nombre())
					|| !nombresMateria.add(CatalogoMateriasTecnologia.normalizar(materia.nombre()))) {
				throw new IllegalArgumentException(
						"Selecciona materias únicas del plan de estudios de la tecnología y semestre indicados.");
			}
			materiasCatalogo.add(new MateriaHorario(
					materia.nombre().trim(),
					CatalogoMateriasTecnologia.carrerasPara(materia.nombre())));
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
				materiasCatalogo);
	}

	private List<MateriaHorario> materiasCompartidas(HorarioTutor horario) {
		return horario.materias().stream()
				.map(materia -> {
					List<String> carreras = CatalogoMateriasTecnologia.carrerasPara(materia.nombre());
					return carreras.isEmpty()
							? materia
							: new MateriaHorario(materia.nombre(), carreras);
				})
				.toList();
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
