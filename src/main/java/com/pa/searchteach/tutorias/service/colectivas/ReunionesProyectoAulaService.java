package com.pa.searchteach.tutorias.service.colectivas;

import java.time.LocalDateTime;
import java.util.UUID;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.dto.colectivas.ReunionProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.RespuestaReunionProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.RespuestaReunionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.SesionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** Programar, responder y consultar reuniones de proyecto de aula. */
@Service
public class ReunionesProyectoAulaService {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final SesionProyectoAulaRepositorio sesionProyectoRepositorio;
	private final RespuestaReunionProyectoAulaRepositorio reunionRepositorio;
	private final NotificationService notificationService;
	private final ActualizacionesTutoriasService actualizacionesTutoriasService;
	private final BusquedaProyectosAula busqueda;

	public ReunionesProyectoAulaService(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			SesionProyectoAulaRepositorio sesionProyectoRepositorio,
			RespuestaReunionProyectoAulaRepositorio reunionRepositorio,
			NotificationService notificationService,
			ActualizacionesTutoriasService actualizacionesTutoriasService,
			BusquedaProyectosAula busqueda) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.sesionProyectoRepositorio = sesionProyectoRepositorio;
		this.reunionRepositorio = reunionRepositorio;
		this.notificationService = notificationService;
		this.actualizacionesTutoriasService = actualizacionesTutoriasService;
		this.busqueda = busqueda;
	}

	public ProyectoAula programarReunionProyecto(
			String tutoriaId, String proyectoId, String sesionId,
			ReunionProyectoAulaSolicitud solicitud, String docenteId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		ProyectoAula proyecto = busqueda.buscarProyecto(tutoria, proyectoId);
		busqueda.validarTutorResponsable(proyecto, docenteId);
		if ("FINALIZADO".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "El proyecto ya fue finalizado.");
		}
		sesionProyectoRepositorio.findByIdAndTutoriaColectivaIdAndProyectoId(sesionId, tutoriaId, proyectoId)
				.orElseThrow(() -> new NotFoundException("No se encontró el reporte asociado a este chat."));
		ProyectoAula actualizado = proyecto.programarReunion(solicitud.fechaReunion(), docenteId, sesionId);
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		reunionRepositorio.save(new RespuestaReunionProyectoAula(
				UUID.randomUUID().toString(), tutoriaId, proyectoId, sesionId,
				solicitud.fechaReunion(), docenteId, java.util.Map.of(), "PENDIENTE", LocalDateTime.now()));
		actualizacionesTutoriasService.publicar("PROYECTO_CAMBIO", tutoriaId);
		String fecha = solicitud.fechaReunion().toString().replace('T', ' ');
		proyecto.estudianteIds().stream()
				.distinct().forEach(destinatario -> notificationService.notifyUser(destinatario,
						"Reunión de proyecto de aula programada",
						"El tutor programó una reunión para " + proyecto.nombre() + " el " + fecha + ".",
						"/notificaciones"));
		return actualizado;
	}

	public RespuestaReunionProyectoAula responderReunion(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId, boolean acepta) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		ProyectoAula proyecto = busqueda.buscarProyecto(tutoria, proyectoId);
		if (!proyecto.estudianteIds().contains(usuarioId)) {
			throw new ForbiddenException("Solo los estudiantes inscritos pueden responder la reunión.");
		}
		RespuestaReunionProyectoAula reunion = reunionRepositorio
				.findTopByTutoriaColectivaIdAndProyectoIdAndSesionIdOrderByActualizadaEnDesc(
						tutoriaId, proyectoId, sesionId)
				.orElseThrow(() -> new NotFoundException("No se encontró la reunión propuesta."));
		if ("CANCELADA".equals(reunion.estado())) return reunion;
		java.util.Map<String, Boolean> respuestas = new java.util.HashMap<>(reunion.respuestas());
		respuestas.put(usuarioId, acepta);
		boolean todosRechazaron = !respuestas.isEmpty()
				&& respuestas.keySet().containsAll(proyecto.estudianteIds())
				&& proyecto.estudianteIds().stream().allMatch(id -> Boolean.FALSE.equals(respuestas.get(id)));
		String estado = todosRechazaron ? "CANCELADA" : "PENDIENTE";
		RespuestaReunionProyectoAula actualizada = new RespuestaReunionProyectoAula(
				reunion.id(), tutoriaId, proyectoId, sesionId, reunion.fechaReunion(),
				reunion.propuestaPorId(), respuestas, estado, LocalDateTime.now());
		reunionRepositorio.save(actualizada);
		actualizacionesTutoriasService.publicar("REUNION_CAMBIO", tutoriaId);
		return actualizada;
	}

	public RespuestaReunionProyectoAula consultarReunion(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		busqueda.validarAccesoLecturaProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		return reunionRepositorio
				.findTopByTutoriaColectivaIdAndProyectoIdAndSesionIdOrderByActualizadaEnDesc(
						tutoriaId, proyectoId, sesionId)
				.orElseThrow(() -> new NotFoundException("No se encontró la reunión propuesta."));
	}
}
