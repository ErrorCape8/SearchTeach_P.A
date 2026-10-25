package com.pa.searchteach.tutorias.service;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.tutorias.dto.PropuestaHorario;
import com.pa.searchteach.tutorias.dto.RegistroAsistencia;
import com.pa.searchteach.tutorias.dto.SolicitudTutoria;
import com.pa.searchteach.tutorias.model.EstadoTutoria;
import com.pa.searchteach.tutorias.model.Tutoria;
import com.pa.searchteach.tutorias.repository.TutoriaRepositorio;
import com.pa.searchteach.notifications.service.NotificationService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class ServicioTutoriasImpl implements ServicioTutorias {

	private final TutoriaRepositorio tutoriaRepositorio;
	private final InscripcionesTutoriasEstudianteService inscripcionesEstudiante;
	private final NotificationService notificationService;

	public ServicioTutoriasImpl(
			TutoriaRepositorio tutoriaRepositorio,
			InscripcionesTutoriasEstudianteService inscripcionesEstudiante,
			NotificationService notificationService) {
		this.tutoriaRepositorio = tutoriaRepositorio;
		this.inscripcionesEstudiante = inscripcionesEstudiante;
		this.notificationService = notificationService;
	}

	@Override
	public Tutoria solicitar(SolicitudTutoria solicitud, String usuarioId) {
		if (!solicitud.estudianteId().equals(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo puedes solicitar tutorías con tu propio identificador de estudiante.");
		}
		validarRango(solicitud.fechaInicio(), solicitud.fechaFin());
		inscripcionesEstudiante.validarNuevaInscripcion(usuarioId,
				solicitud.fechaInicio(), solicitud.fechaFin(), null, null);

		Tutoria tutoria = new Tutoria();
		tutoria.setEstudianteId(solicitud.estudianteId());
		tutoria.setDocenteId(solicitud.docenteId());
		tutoria.setMateria(solicitud.materia());
		tutoria.setModalidad(solicitud.modalidad());
		tutoria.setFechaInicio(solicitud.fechaInicio());
		tutoria.setFechaFin(solicitud.fechaFin());
		tutoria.setEstado(EstadoTutoria.SOLICITADA);
		Tutoria guardada = tutoriaRepositorio.save(tutoria);
		notificationService.notifyUser(guardada.getDocenteId(), "Nueva solicitud de tutoria",
				"Tienes una solicitud de " + guardada.getMateria() + " pendiente de revisar.", "/notificaciones");
				notificationService.notifyUser(guardada.getEstudianteId(), "Solicitud enviada",
						"Tu solicitud de tutoria de " + guardada.getMateria() + " fue enviada al docente.", "/notificaciones");
		return guardada;
	}

	@Override
	public List<Tutoria> listarDelUsuario(String usuarioId) {
		return tutoriaRepositorio.findByEstudianteIdOrDocenteId(usuarioId, usuarioId);
	}

	@Override
	public Tutoria buscar(String id, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarParticipante(tutoria, usuarioId);
		return tutoria;
	}

	@Override
	public Tutoria aceptar(String id, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarDocente(tutoria, usuarioId);
		exigirEstado(tutoria, EstadoTutoria.SOLICITADA);
		inscripcionesEstudiante.validarNuevaInscripcion(tutoria.getEstudianteId(),
				tutoria.getFechaInicio(), tutoria.getFechaFin(), null, tutoria.getId());
		validarConflictoEstudiante(tutoria, tutoria.getFechaInicio(), tutoria.getFechaFin());
		tutoria.setEstado(EstadoTutoria.PROGRAMADA);
		Tutoria guardada = tutoriaRepositorio.save(tutoria);
		notificationService.notifyUser(guardada.getEstudianteId(), "Tutoria aceptada",
				"Tu solicitud de " + guardada.getMateria() + " fue aceptada.", "/notificaciones");
		return guardada;
	}

	@Override
	public Tutoria proponerHorario(String id, PropuestaHorario propuesta, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarDocente(tutoria, usuarioId);
		exigirEstado(tutoria, EstadoTutoria.SOLICITADA);
		validarRango(propuesta.fechaInicio(), propuesta.fechaFin());
		validarConflictoEstudiante(tutoria, propuesta.fechaInicio(), propuesta.fechaFin());
		tutoria.setFechaAlternativaInicio(propuesta.fechaInicio());
		tutoria.setFechaAlternativaFin(propuesta.fechaFin());
		tutoria.setEstado(EstadoTutoria.ALTERNATIVA_PROPUESTA);
		Tutoria guardada = tutoriaRepositorio.save(tutoria);
		notificationService.notifyUser(guardada.getEstudianteId(), "Nueva propuesta de horario",
				"El docente propuso otro horario para " + guardada.getMateria() + ".", "/notificaciones");
		return guardada;
	}

	@Override
	public Tutoria confirmarAlternativa(String id, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarEstudiante(tutoria, usuarioId);
		exigirEstado(tutoria, EstadoTutoria.ALTERNATIVA_PROPUESTA);
		inscripcionesEstudiante.validarNuevaInscripcion(tutoria.getEstudianteId(),
				tutoria.getFechaAlternativaInicio(), tutoria.getFechaAlternativaFin(), null, tutoria.getId());
		validarConflictoEstudiante(
				tutoria, tutoria.getFechaAlternativaInicio(), tutoria.getFechaAlternativaFin());
		tutoria.setFechaInicio(tutoria.getFechaAlternativaInicio());
		tutoria.setFechaFin(tutoria.getFechaAlternativaFin());
		tutoria.setFechaAlternativaInicio(null);
		tutoria.setFechaAlternativaFin(null);
		tutoria.setEstado(EstadoTutoria.PROGRAMADA);
		Tutoria guardada = tutoriaRepositorio.save(tutoria);
		notificationService.notifyUser(guardada.getDocenteId(), "Horario confirmado",
				"El estudiante confirmo el horario de " + guardada.getMateria() + ".", "/notificaciones");
		return guardada;
	}

	@Override
	public Tutoria cancelar(String id, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarParticipante(tutoria, usuarioId);
		if (tutoria.getEstado() == EstadoTutoria.EN_CURSO
				|| tutoria.getEstado() == EstadoTutoria.REALIZADA
				|| tutoria.getEstado() == EstadoTutoria.CANCELADA) {
			throw conflictoEstado();
		}
		tutoria.setEstado(EstadoTutoria.CANCELADA);
		Tutoria guardada = tutoriaRepositorio.save(tutoria);
		String destinatario = usuarioId.equals(guardada.getEstudianteId())
				? guardada.getDocenteId() : guardada.getEstudianteId();
		notificationService.notifyUser(destinatario, "Tutoria cancelada",
				"La tutoria de " + guardada.getMateria() + " fue cancelada.", "/notificaciones");
		notificationService.notifyUser(usuarioId, "Cancelacion confirmada",
				"Cancelaste la tutoria de " + guardada.getMateria() + ".", "/notificaciones");
		return guardada;
	}

	@Override
	public Tutoria iniciar(String id, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarDocente(tutoria, usuarioId);
		exigirEstado(tutoria, EstadoTutoria.PROGRAMADA);
		tutoria.setEstado(EstadoTutoria.EN_CURSO);
		Tutoria guardada = tutoriaRepositorio.save(tutoria);
		notificationService.notifyUser(guardada.getEstudianteId(), "Tutoria iniciada",
				"El docente inicio tu tutoria de " + guardada.getMateria() + ".", "/notificaciones");
		return guardada;
	}

	@Override
	public Tutoria finalizar(String id, RegistroAsistencia asistencia, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarDocente(tutoria, usuarioId);
		exigirEstado(tutoria, EstadoTutoria.EN_CURSO);
		tutoria.setAsistio(asistencia.asistio());
		tutoria.setEstado(EstadoTutoria.REALIZADA);
		Tutoria guardada = tutoriaRepositorio.save(tutoria);
		notificationService.notifyUser(guardada.getEstudianteId(), "Tutoria finalizada",
				"La tutoria de " + guardada.getMateria() + " finalizo.", "/notificaciones");
		return guardada;
	}

	private Tutoria buscarExistente(String id) {
		return tutoriaRepositorio.findById(id)
				.orElseThrow(() -> new ResponseStatusException(
						HttpStatus.NOT_FOUND, "No se encontró la tutoría solicitada."));
	}

	private void validarConflictoEstudiante(
			Tutoria actual, LocalDateTime fechaInicio, LocalDateTime fechaFin) {
		inscripcionesEstudiante.validarConflictoActual(
				actual.getEstudianteId(), fechaInicio, fechaFin, actual.getId());
		boolean hayCruce = tutoriaRepositorio.findByEstudianteId(actual.getEstudianteId()).stream()
				.filter(otra -> !otra.getId().equals(actual.getId()))
				.filter(otra -> otra.getEstado() == EstadoTutoria.PROGRAMADA
						|| otra.getEstado() == EstadoTutoria.EN_CURSO)
				.anyMatch(otra -> fechaInicio.isBefore(otra.getFechaFin())
						&& otra.getFechaInicio().isBefore(fechaFin));
		if (hayCruce) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El horario se cruza con otra tutoría programada del estudiante.");
		}
	}

	private void validarRango(LocalDateTime fechaInicio, LocalDateTime fechaFin) {
		if (!fechaFin.isAfter(fechaInicio)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"La fecha de finalización debe ser posterior a la fecha de inicio.");
		}
	}

	private void exigirEstado(Tutoria tutoria, EstadoTutoria estadoEsperado) {
		if (tutoria.getEstado() != estadoEsperado) {
			throw conflictoEstado();
		}
	}

	private ResponseStatusException conflictoEstado() {
		return new ResponseStatusException(
				HttpStatus.CONFLICT, "La tutoría no permite esta acción en su estado actual.");
	}

	private void validarParticipante(Tutoria tutoria, String usuarioId) {
		if (!tutoria.getEstudianteId().equals(usuarioId)
				&& !tutoria.getDocenteId().equals(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"No tienes acceso a esta tutoría.");
		}
	}

	private void validarEstudiante(Tutoria tutoria, String usuarioId) {
		if (!tutoria.getEstudianteId().equals(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo el estudiante asociado puede realizar esta acción.");
		}
	}

	private void validarDocente(Tutoria tutoria, String usuarioId) {
		if (!tutoria.getDocenteId().equals(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo el docente asociado puede realizar esta acción.");
		}
	}
}
