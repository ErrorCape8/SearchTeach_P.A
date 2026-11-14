package com.pa.searchteach.tutorias.service.grupal;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.dto.grupal.ResolverSolicitudCambioFecha;
import com.pa.searchteach.tutorias.dto.grupal.SolicitudCambioFechaTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.model.SolicitudCambioFechaSesion;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.tutorias.repository.SolicitudCambioFechaSesionRepositorio;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import static com.pa.searchteach.tutorias.service.grupal.RelojTutorias.ahora;

/** Solicitudes de cambio de fecha de los docentes y su resolución por coordinación. */
@Service
public class CambioFechaSesionService {

	private final SesionTutoriaRepositorio sesiones;
	private final UserRepository usuarios;
	private final CoordinatorRepository coordinadores;
	private final SolicitudCambioFechaSesionRepositorio solicitudesCambio;
	private final NotificationService notificationService;

	public CambioFechaSesionService(
			SesionTutoriaRepositorio sesiones,
			UserRepository usuarios,
			CoordinatorRepository coordinadores,
			SolicitudCambioFechaSesionRepositorio solicitudesCambio,
			NotificationService notificationService) {
		this.sesiones = sesiones;
		this.usuarios = usuarios;
		this.coordinadores = coordinadores;
		this.solicitudesCambio = solicitudesCambio;
		this.notificationService = notificationService;
	}

	public void solicitarCambioFecha(String sesionId, String docenteId,
			SolicitudCambioFechaTutoria solicitud) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
						"No se encontró la tutoría seleccionada."));
		if (!sesion.docenteId().equals(docenteId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo puedes solicitar cambios para tus propias tutorías.");
		}
		LocalDateTime ahora = ahora();
		if ("FINALIZADA".equals(sesion.estadoClase())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"No puedes cambiar la fecha de una tutoría que ya comenzó.");
		}
		if (solicitud.fechaInicio() == null || solicitud.fechaFin() == null
				|| !solicitud.fechaInicio().isAfter(ahora)
				|| !solicitud.fechaFin().isAfter(solicitud.fechaInicio())
				|| solicitud.fechaInicio().equals(sesion.fechaInicio())
				|| !solicitud.fechaFin().equals(solicitud.fechaInicio().plus(
						java.time.Duration.between(sesion.fechaInicio(), sesion.fechaFin())))) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Selecciona una nueva fecha futura y un horario válido.");
		}
		User docente = usuarios.findById(docenteId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
						"No se encontró el docente."));
		List<Coordinator> coordinadoresDisponibles = coordinadores.findAll();
		if (coordinadoresDisponibles.isEmpty()) {
			throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
					"No hay cuentas de coordinación disponibles para recibir la solicitud.");
		}
		if (solicitudesCambio.existsBySesionIdAndEstado(sesionId, "PENDIENTE")) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Esta tutoría ya tiene una solicitud pendiente.");
		}
		String nombreDocente = docente.getNombre() == null ? docenteId : docente.getNombre().trim();
		SolicitudCambioFechaSesion guardada = solicitudesCambio.save(
				SolicitudCambioFechaSesion.pendiente(sesionId, docenteId, nombreDocente, sesion.materia(),
						sesion.fechaInicio(), sesion.fechaFin(), solicitud.fechaInicio(), solicitud.fechaFin(),
						solicitud.motivo().trim()));
		String mensaje = nombreDocente + " solicita cambiar la tutoría de "
				+ sesion.materia() + " (" + sesion.fechaInicio() + "–" + sesion.fechaFin()
				+ ") a " + solicitud.fechaInicio() + "–" + solicitud.fechaFin()
				+ ". Motivo: " + solicitud.motivo().trim();
		coordinadoresDisponibles.forEach(coordinador -> notificationService.notifyUser(
				coordinador.getId(), "Solicitud de cambio de fecha", mensaje,
				"/coordinacion/solicitudes?request=" + guardada.id()));
	}

	public List<SolicitudCambioFechaSesion> listarSolicitudesCambioPendientes() {
		return solicitudesCambio.findByEstadoOrderByCreadaEnAsc("PENDIENTE");
	}

	public SolicitudCambioFechaSesion resolverSolicitudCambio(String solicitudId,
			ResolverSolicitudCambioFecha resolucion) {
		SolicitudCambioFechaSesion solicitud = solicitudesCambio.findById(solicitudId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la solicitud."));
		if (!"PENDIENTE".equals(solicitud.estado())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "La solicitud ya fue atendida.");
		}
		String accion = resolucion.accion().trim().toUpperCase(java.util.Locale.ROOT);
		SesionTutoria sesion = sesiones.findById(solicitud.sesionId()).orElse(null);
		String titulo;
		String mensaje;
		String estado;
		String razon = null;
		switch (accion) {
			case "REPROGRAMAR" -> {
				if (sesion == null || resolucion.fechaInicio() == null) {
					throw new ResponseStatusException(HttpStatus.CONFLICT,
							"La tutoría ya no existe o falta seleccionar fecha y hora.");
				}
				LocalDateTime nuevoInicio = resolucion.fechaInicio();
				java.time.Duration duracion = java.time.Duration.between(sesion.fechaInicio(), sesion.fechaFin());
				LocalDateTime nuevoFin = nuevoInicio.plus(duracion);
				if (!nuevoInicio.isAfter(ahora())) {
					throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona una fecha futura.");
				}
				boolean conflicto = sesiones.findByDocenteId(sesion.docenteId()).stream()
						.filter(otra -> !otra.id().equals(sesion.id()))
						.anyMatch(otra -> nuevoInicio.isBefore(otra.fechaFin()) && otra.fechaInicio().isBefore(nuevoFin));
				if (conflicto) throw new ResponseStatusException(HttpStatus.CONFLICT,
						"El docente ya tiene otra tutoría en ese horario.");
				sesiones.save(new SesionTutoria(sesion.id(), sesion.docenteId(), sesion.estudianteIds(),
						nuevoInicio, nuevoFin, sesion.tecnologia(), sesion.semestre(), sesion.asistencias(),
						sesion.materia(), sesion.tecnologias(), sesion.modalidad(), sesion.ubicacion()));
				estado = "ACEPTADA";
				titulo = "Cambio de tutoría aprobado";
				mensaje = "Coordinación reprogramó " + solicitud.materia() + " para " + nuevoInicio + "–" + nuevoFin + ".";
			}
			case "ASIGNAR_MAS_TARDE" -> {
				if (sesion != null) sesiones.delete(sesion);
				estado = "ASIGNAR_MAS_TARDE";
				titulo = "Tutoría retirada";
				mensaje = "Coordinación retiró la tutoría de " + solicitud.materia()
						+ ". Se te asignará otra más adelante.";
			}
			case "DENEGAR" -> {
				razon = resolucion.motivoDenegacion() == null ? "" : resolucion.motivoDenegacion().trim();
				if (razon.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Indica el motivo de la denegación.");
				estado = "DENEGADA";
				titulo = "Solicitud de cambio denegada";
				mensaje = "No se aprobó el cambio de " + solicitud.materia() + ". Motivo: " + razon;
			}
			default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Acción no válida.");
		}
		SolicitudCambioFechaSesion resuelta = solicitudesCambio.save(solicitud.resolver(estado, razon));
		notificationService.notifyUser(solicitud.docenteId(), titulo, mensaje, "/docente");
		return resuelta;
	}
}
