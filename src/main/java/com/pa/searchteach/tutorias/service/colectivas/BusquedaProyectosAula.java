package com.pa.searchteach.tutorias.service.colectivas;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.SesionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.stereotype.Component;

/** Búsquedas y validaciones de acceso compartidas por los servicios de proyectos de aula. */
@Component
public class BusquedaProyectosAula {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final UserRepository userRepository;
	private final SesionProyectoAulaRepositorio sesionProyectoRepositorio;

	public BusquedaProyectosAula(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			UserRepository userRepository,
			SesionProyectoAulaRepositorio sesionProyectoRepositorio) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.userRepository = userRepository;
		this.sesionProyectoRepositorio = sesionProyectoRepositorio;
	}

	public TutoriaColectiva buscarTutoria(String id) {
		return tutoriaColectivaRepositorio.findById(id)
				.orElseThrow(() -> new NotFoundException("No se encontró la tutoría colectiva."));
	}

	public ProyectoAula buscarProyecto(TutoriaColectiva tutoria, String proyectoId) {
		return tutoria.proyectos().stream()
				.filter(proyecto -> proyecto.proyectoId().equals(proyectoId))
				.findFirst()
				.orElseThrow(() -> new NotFoundException("No se encontró el espacio de proyecto."));
	}

	public User buscarEstudiante(String id) {
		return userRepository.findById(id)
				.orElseThrow(() -> new NotFoundException("No se encontró el usuario estudiante."));
	}

	public void validarTutorResponsable(ProyectoAula proyecto, String docenteId) {
		if (!proyecto.docenteResponsableId().equals(docenteId)) {
			throw new ForbiddenException("Solo el docente de apoyo asignado puede gestionar este proyecto.");
		}
	}

	public void validarAccesoLecturaProyecto(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		if (!proyecto.docenteResponsableId().equals(usuarioId)
				&& !proyecto.estudianteIds().contains(usuarioId)
				&& !tutoria.docenteLiderId().equals(usuarioId)) {
			throw new ForbiddenException("Solo los participantes y el docente líder pueden consultar el historial.");
		}
		sesionProyectoRepositorio.findByIdAndTutoriaColectivaIdAndProyectoId(sesionId, tutoriaId, proyectoId)
				.orElseThrow(() -> new NotFoundException("No se encontró el reporte del proyecto."));
	}

	public void validarAccesoParticipanteProyecto(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		if (!proyecto.docenteResponsableId().equals(usuarioId)
				&& !proyecto.estudianteIds().contains(usuarioId)) {
			throw new ForbiddenException("El docente líder puede consultar el historial, pero no participar en el chat.");
		}
		sesionProyectoRepositorio.findByIdAndTutoriaColectivaIdAndProyectoId(sesionId, tutoriaId, proyectoId)
				.orElseThrow(() -> new NotFoundException("No se encontró el reporte del proyecto."));
	}
}
