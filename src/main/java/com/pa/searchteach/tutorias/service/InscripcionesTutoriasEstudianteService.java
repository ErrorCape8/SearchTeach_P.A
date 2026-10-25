package com.pa.searchteach.tutorias.service;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.tutorias.model.EstadoTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.model.Tutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaRepositorio;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class InscripcionesTutoriasEstudianteService {

	private static final int MAX_INSCRIPCIONES_ACTIVAS = 3;

	private final SesionTutoriaRepositorio sesiones;
	private final TutoriaRepositorio tutorias;

	public InscripcionesTutoriasEstudianteService(
			SesionTutoriaRepositorio sesiones,
			TutoriaRepositorio tutorias) {
		this.sesiones = sesiones;
		this.tutorias = tutorias;
	}

	public void validarNuevaInscripcion(
			String estudianteId,
			LocalDateTime fechaInicio,
			LocalDateTime fechaFin,
			String sesionAExcluir,
			String tutoriaAExcluir) {
		LocalDateTime ahora = LocalDateTime.now();
		List<SesionTutoria> grupalesActivas = sesiones.findByEstudianteIdsContaining(estudianteId).stream()
				.filter(sesion -> !sesion.id().equals(sesionAExcluir))
				.filter(sesion -> sesion.fechaFin().isAfter(ahora))
				.toList();
		List<Tutoria> individualesActivas = tutorias.findByEstudianteId(estudianteId).stream()
				.filter(tutoria -> !tutoria.getId().equals(tutoriaAExcluir))
				.filter(this::estaActiva)
				.filter(tutoria -> tutoria.getFechaFin() != null && tutoria.getFechaFin().isAfter(ahora))
				.toList();

		if (grupalesActivas.size() + individualesActivas.size() >= MAX_INSCRIPCIONES_ACTIVAS) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Ya tienes el máximo de tres tutorías inscritas. Cancela una para inscribirte en otra.");
		}
		validarCruceHorario(fechaInicio, fechaFin, grupalesActivas, individualesActivas);
	}

	public void validarCruceHorario(
			LocalDateTime fechaInicio,
			LocalDateTime fechaFin,
			List<SesionTutoria> grupales,
			List<Tutoria> individuales) {
		boolean cruceGrupal = grupales.stream()
				.anyMatch(sesion -> seCruzan(fechaInicio, fechaFin, sesion.fechaInicio(), sesion.fechaFin()));
		boolean cruceIndividual = individuales.stream()
				.filter(tutoria -> tutoria.getFechaInicio() != null && tutoria.getFechaFin() != null)
				.anyMatch(tutoria -> seCruzan(fechaInicio, fechaFin,
						tutoria.getFechaInicio(), tutoria.getFechaFin()));
		if (cruceGrupal || cruceIndividual) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El horario se cruza con otra tutoría que ya tienes inscrita.");
		}
	}

	public void validarConflictoActual(
			String estudianteId,
			LocalDateTime fechaInicio,
			LocalDateTime fechaFin,
			String tutoriaAExcluir) {
		LocalDateTime ahora = LocalDateTime.now();
		List<SesionTutoria> grupalesActivas = sesiones.findByEstudianteIdsContaining(estudianteId).stream()
				.filter(sesion -> !sesion.id().equals(tutoriaAExcluir))
				.filter(sesion -> sesion.fechaFin().isAfter(ahora))
				.toList();
		List<Tutoria> individualesActivas = tutorias.findByEstudianteId(estudianteId).stream()
				.filter(tutoria -> !tutoria.getId().equals(tutoriaAExcluir))
				.filter(this::estaActiva)
				.filter(tutoria -> tutoria.getFechaFin() != null && tutoria.getFechaFin().isAfter(ahora))
				.toList();
		validarCruceHorario(fechaInicio, fechaFin, grupalesActivas, individualesActivas);
	}

	private boolean estaActiva(Tutoria tutoria) {
		return tutoria.getEstado() == EstadoTutoria.SOLICITADA
				|| tutoria.getEstado() == EstadoTutoria.ALTERNATIVA_PROPUESTA
				|| tutoria.getEstado() == EstadoTutoria.PROGRAMADA
				|| tutoria.getEstado() == EstadoTutoria.EN_CURSO;
	}

	private boolean seCruzan(
			LocalDateTime inicioNuevo,
			LocalDateTime finNuevo,
			LocalDateTime inicioExistente,
			LocalDateTime finExistente) {
		return inicioExistente != null && finExistente != null
				&& inicioNuevo.isBefore(finExistente)
				&& inicioExistente.isBefore(finNuevo);
	}
}
