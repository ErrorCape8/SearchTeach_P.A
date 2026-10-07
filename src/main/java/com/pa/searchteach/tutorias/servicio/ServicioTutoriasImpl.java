package com.pa.searchteach.tutorias.servicio;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.tutorias.dto.PropuestaHorario;
import com.pa.searchteach.tutorias.dto.RegistroAsistencia;
import com.pa.searchteach.tutorias.dto.SolicitudTutoria;
import com.pa.searchteach.tutorias.modelo.EstadoTutoria;
import com.pa.searchteach.tutorias.modelo.Tutoria;
import com.pa.searchteach.tutorias.repositorio.TutoriaRepositorio;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class ServicioTutoriasImpl implements ServicioTutorias {

	private final TutoriaRepositorio tutoriaRepositorio;

	public ServicioTutoriasImpl(TutoriaRepositorio tutoriaRepositorio) {
		this.tutoriaRepositorio = tutoriaRepositorio;
	}

	@Override
	public Tutoria solicitar(SolicitudTutoria solicitud, String usuarioId) {
		if (!solicitud.estudianteId().equals(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo puedes solicitar tutorías con tu propio identificador de estudiante.");
		}
		validarRango(solicitud.fechaInicio(), solicitud.fechaFin());

		Tutoria tutoria = new Tutoria();
		tutoria.setEstudianteId(solicitud.estudianteId());
		tutoria.setDocenteId(solicitud.docenteId());
		tutoria.setMateria(solicitud.materia());
		tutoria.setModalidad(solicitud.modalidad());
		tutoria.setFechaInicio(solicitud.fechaInicio());
		tutoria.setFechaFin(solicitud.fechaFin());
		tutoria.setEstado(EstadoTutoria.SOLICITADA);
		return tutoriaRepositorio.save(tutoria);
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
		validarConflictoEstudiante(tutoria, tutoria.getFechaInicio(), tutoria.getFechaFin());
		tutoria.setEstado(EstadoTutoria.PROGRAMADA);
		return tutoriaRepositorio.save(tutoria);
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
		return tutoriaRepositorio.save(tutoria);
	}

	@Override
	public Tutoria confirmarAlternativa(String id, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarEstudiante(tutoria, usuarioId);
		exigirEstado(tutoria, EstadoTutoria.ALTERNATIVA_PROPUESTA);
		validarConflictoEstudiante(
				tutoria, tutoria.getFechaAlternativaInicio(), tutoria.getFechaAlternativaFin());
		tutoria.setFechaInicio(tutoria.getFechaAlternativaInicio());
		tutoria.setFechaFin(tutoria.getFechaAlternativaFin());
		tutoria.setFechaAlternativaInicio(null);
		tutoria.setFechaAlternativaFin(null);
		tutoria.setEstado(EstadoTutoria.PROGRAMADA);
		return tutoriaRepositorio.save(tutoria);
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
		return tutoriaRepositorio.save(tutoria);
	}

	@Override
	public Tutoria iniciar(String id, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarDocente(tutoria, usuarioId);
		exigirEstado(tutoria, EstadoTutoria.PROGRAMADA);
		tutoria.setEstado(EstadoTutoria.EN_CURSO);
		return tutoriaRepositorio.save(tutoria);
	}

	@Override
	public Tutoria finalizar(String id, RegistroAsistencia asistencia, String usuarioId) {
		Tutoria tutoria = buscarExistente(id);
		validarDocente(tutoria, usuarioId);
		exigirEstado(tutoria, EstadoTutoria.EN_CURSO);
		tutoria.setAsistio(asistencia.asistio());
		tutoria.setEstado(EstadoTutoria.REALIZADA);
		return tutoriaRepositorio.save(tutoria);
	}

	private Tutoria buscarExistente(String id) {
		return tutoriaRepositorio.findById(id)
				.orElseThrow(() -> new ResponseStatusException(
						HttpStatus.NOT_FOUND, "No se encontró la tutoría solicitada."));
	}

	private void validarConflictoEstudiante(
			Tutoria actual, LocalDateTime fechaInicio, LocalDateTime fechaFin) {
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
