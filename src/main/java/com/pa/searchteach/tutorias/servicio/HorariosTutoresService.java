package com.pa.searchteach.tutorias.servicio;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Locale;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.tutorias.dto.DocenteCoordinacion;
import com.pa.searchteach.tutorias.dto.HorarioTutorSolicitud;
import com.pa.searchteach.tutorias.modelo.HorarioTutor;
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

	private HorarioTutor construir(String id, String docenteId, HorarioTutorSolicitud solicitud) {
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
				LocalDateTime.now());
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

	private String valor(String value) {
		return value == null ? "" : value.trim();
	}
}
