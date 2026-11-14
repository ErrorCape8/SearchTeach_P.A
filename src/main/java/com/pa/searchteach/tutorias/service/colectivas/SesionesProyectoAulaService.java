package com.pa.searchteach.tutorias.service.colectivas;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.dto.colectivas.SesionProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.SesionProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.SesionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** Reportes de sesión del tutor de apoyo y su confirmación por el docente líder. */
@Service
public class SesionesProyectoAulaService {

	private final SesionProyectoAulaRepositorio sesionProyectoRepositorio;
	private final NotificationService notificationService;
	private final ActualizacionesTutoriasService actualizacionesTutoriasService;
	private final BusquedaProyectosAula busqueda;

	public SesionesProyectoAulaService(
			SesionProyectoAulaRepositorio sesionProyectoRepositorio,
			NotificationService notificationService,
			ActualizacionesTutoriasService actualizacionesTutoriasService,
			BusquedaProyectosAula busqueda) {
		this.sesionProyectoRepositorio = sesionProyectoRepositorio;
		this.notificationService = notificationService;
		this.actualizacionesTutoriasService = actualizacionesTutoriasService;
		this.busqueda = busqueda;
	}

	public SesionProyectoAula registrarSesionProyecto(
			String tutoriaId, String proyectoId, SesionProyectoAulaSolicitud solicitud, String docenteId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		ProyectoAula proyecto = busqueda.buscarProyecto(tutoria, proyectoId);
		if (!proyecto.docenteResponsableId().equals(docenteId)) {
			throw new ForbiddenException("Solo el tutor asignado a este proyecto puede registrar sus sesiones.");
		}
		if ("FINALIZADO".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "No puedes agregar sesiones a un proyecto finalizado.");
		}
		if (!solicitud.fechaFin().isAfter(solicitud.fechaInicio())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"La hora de finalización debe ser posterior a la hora de inicio.");
		}
		SesionProyectoAula sesion = new SesionProyectoAula(
				UUID.randomUUID().toString(), tutoriaId, proyectoId, docenteId,
				solicitud.fechaInicio(), solicitud.fechaFin(), solicitud.contenido().trim(), LocalDateTime.now());
		SesionProyectoAula guardada = sesionProyectoRepositorio.save(sesion);
		actualizacionesTutoriasService.publicar("PROYECTO_SESION_CAMBIO", tutoriaId);
		notificationService.notifyUser(tutoria.docenteLiderId(), "Nuevo reporte de proyecto de aula",
				"El tutor de apoyo registró un reporte para " + proyecto.nombre() + ". Revísalo en el panel docente.",
				"/docente");
		proyecto.estudianteIds().forEach(estudianteId -> notificationService.notifyUser(
				estudianteId, "Nuevo seguimiento de proyecto",
				"El tutor actualizó el horario y las notas de " + proyecto.nombre() + ".", "/notificaciones"));
		return guardada;
	}

	public SesionProyectoAula confirmarReporteProyecto(
			String tutoriaId, String proyectoId, String sesionId, String docenteLiderId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		if (!tutoria.docenteLiderId().equals(docenteLiderId)) {
			throw new ForbiddenException("Solo el docente líder puede confirmar un reporte de apoyo.");
		}
		busqueda.buscarProyecto(tutoria, proyectoId);
		SesionProyectoAula sesion = sesionProyectoRepositorio
				.findByIdAndTutoriaColectivaIdAndProyectoId(sesionId, tutoriaId, proyectoId)
				.orElseThrow(() -> new NotFoundException("No se encontró el reporte del proyecto."));
		if (sesion.confirmadoPorLiderId() != null) return sesion;
		SesionProyectoAula confirmada = sesion.confirmar(docenteLiderId, LocalDateTime.now());
		sesionProyectoRepositorio.save(confirmada);
		actualizacionesTutoriasService.publicar("PROYECTO_SESION_CAMBIO", tutoriaId);
		notificationService.notifyUser(sesion.docenteId(), "Reporte de apoyo confirmado",
				"El docente líder confirmó el reporte registrado para el proyecto.", "/docente");
		return confirmada;
	}

	public List<SesionProyectoAula> listarSesionesProyectoDocente(
			String tutoriaId, String proyectoId, String docenteId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		ProyectoAula proyecto = busqueda.buscarProyecto(tutoria, proyectoId);
		if (!proyecto.docenteResponsableId().equals(docenteId) && !tutoria.docenteLiderId().equals(docenteId)) {
			throw new ForbiddenException("Solo el tutor asignado y el docente líder pueden consultar este reporte.");
		}
		return sesionProyectoRepositorio.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInicioDesc(
				tutoriaId, proyectoId);
	}
}
