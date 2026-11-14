package com.pa.searchteach.tutorias.service.colectivas;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.SesionProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.SesionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** Solicitud y confirmación del cierre de un proyecto de aula. */
@Service
public class CierreProyectosAulaService {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final SesionProyectoAulaRepositorio sesionProyectoRepositorio;
	private final NotificationService notificationService;
	private final ActualizacionesTutoriasService actualizacionesTutoriasService;
	private final BusquedaProyectosAula busqueda;

	public CierreProyectosAulaService(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			SesionProyectoAulaRepositorio sesionProyectoRepositorio,
			NotificationService notificationService,
			ActualizacionesTutoriasService actualizacionesTutoriasService,
			BusquedaProyectosAula busqueda) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.sesionProyectoRepositorio = sesionProyectoRepositorio;
		this.notificationService = notificationService;
		this.actualizacionesTutoriasService = actualizacionesTutoriasService;
		this.busqueda = busqueda;
	}

	public ProyectoAula solicitarCierreProyecto(
			String tutoriaId, String proyectoId, String motivo, String reporte, String docenteId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		ProyectoAula proyecto = busqueda.buscarProyecto(tutoria, proyectoId);
		busqueda.validarTutorResponsable(proyecto, docenteId);
		String motivoNormalizado = motivo == null ? "" : motivo.trim().toUpperCase(Locale.ROOT);
		if (!List.of("LISTO", "SIN_ATENCION").contains(motivoNormalizado)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona un motivo válido para finalizar el proyecto.");
		}
		if (reporte == null || reporte.isBlank() || reporte.length() > 4000) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"El reporte de finalización es obligatorio y admite hasta 4000 caracteres.");
		}
		if (!"EN_CURSO".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "El proyecto no está disponible para solicitar cierre.");
		}
		ProyectoAula actualizado = proyecto.solicitarCierre(motivoNormalizado).conReporteCierre(reporte.trim());
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		actualizacionesTutoriasService.publicar("PROYECTO_CAMBIO", tutoriaId);
		notificationService.notifyUser(tutoria.docenteLiderId(), "Proyecto pendiente de confirmación",
				"El tutor solicitó finalizar " + proyecto.nombre() + ". Revisa el reporte y confirma el cierre.",
				"/docente");
		return actualizado;
	}

	public ProyectoAula responderSolicitudCierre(
			String tutoriaId, String proyectoId, boolean confirmar, String docenteLiderId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		if (!tutoria.docenteLiderId().equals(docenteLiderId)) {
			throw new ForbiddenException("Solo el docente líder puede confirmar el cierre del proyecto.");
		}
		ProyectoAula proyecto = busqueda.buscarProyecto(tutoria, proyectoId);
		if (!"PENDIENTE_CONFIRMACION".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "No hay una solicitud de cierre pendiente.");
		}
		List<SesionProyectoAula> reportes = sesionProyectoRepositorio
				.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInicioDesc(tutoriaId, proyectoId);
		if (confirmar && (reportes.isEmpty()
				|| reportes.stream().anyMatch(sesion -> sesion.confirmadoPorLiderId() == null
						|| sesion.fechaFin().isAfter(LocalDateTime.now())))) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Todas las sesiones deben haber terminado y estar confirmadas antes de finalizar el proyecto.");
		}
		ProyectoAula actualizado = confirmar
				? proyecto.confirmarCierre(docenteLiderId, LocalDateTime.now())
				: proyecto.rechazarCierre();
		TutoriaColectiva actualizada = tutoria.actualizarProyecto(actualizado);
		if (confirmar && todosLosProyectosConfirmados(actualizada)) {
			actualizada = actualizada.disolver();
		}
		tutoriaColectivaRepositorio.save(actualizada);
		actualizacionesTutoriasService.publicar("PROYECTO_CAMBIO", tutoriaId);
		if (confirmar && "DISUELTA".equals(actualizada.estado())) {
			notificationService.notifyUser(tutoria.coordinadoraId(), "Grupo de proyecto disuelto",
					"Todos los reportes fueron confirmados y el grupo quedó archivado.", "/notificaciones");
		}
		notificationService.notifyUser(proyecto.docenteResponsableId(),
				confirmar ? "Proyecto de aula finalizado" : "Solicitud de cierre devuelta",
				confirmar ? "El docente líder confirmó el cierre de " + proyecto.nombre() + "."
						: "El docente líder devolvió la solicitud de cierre de " + proyecto.nombre() + ".",
				"/docente");
		proyecto.estudianteIds().forEach(estudianteId -> notificationService.notifyUser(estudianteId,
				confirmar ? "Proyecto de aula finalizado" : "Solicitud de cierre en revisión",
				confirmar ? "El docente líder confirmó el cierre de " + proyecto.nombre() + "."
						: "El docente líder pidió revisar la solicitud de cierre de " + proyecto.nombre() + ".",
				"/notificaciones"));
		return actualizado;
	}

	private boolean todosLosProyectosConfirmados(TutoriaColectiva tutoria) {
		return !tutoria.proyectos().isEmpty()
				&& tutoria.proyectos().stream().allMatch(proyecto -> {
					List<SesionProyectoAula> sesiones = sesionProyectoRepositorio
							.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInicioDesc(
									tutoria.id(), proyecto.proyectoId());
					return !sesiones.isEmpty()
							&& sesiones.stream().allMatch(sesion -> sesion.confirmadoPorLiderId() != null);
				});
	}
}
