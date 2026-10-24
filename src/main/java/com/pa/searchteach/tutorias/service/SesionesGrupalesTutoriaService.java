package com.pa.searchteach.tutorias.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import com.pa.searchteach.tutorias.dto.InscripcionTutoriaGrupal;
import com.pa.searchteach.tutorias.dto.ProgramarTutoriasSolicitud;
import com.pa.searchteach.tutorias.dto.SolicitudCambioFechaTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.tutorias.repository.SolicitudCambioFechaSesionRepositorio;
import com.pa.searchteach.tutorias.model.SolicitudCambioFechaSesion;
import com.pa.searchteach.tutorias.dto.ResolverSolicitudCambioFecha;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class SesionesGrupalesTutoriaService {

	private final SesionTutoriaRepositorio sesiones;
	private final UserRepository usuarios;
	private final HorariosTutoresService horarios;
	private final NotificationService notificationService;
	private final SolicitudCambioFechaSesionRepositorio solicitudesCambio;

	public SesionesGrupalesTutoriaService(
			SesionTutoriaRepositorio sesiones,
			UserRepository usuarios,
			HorariosTutoresService horarios,
			NotificationService notificationService,
			SolicitudCambioFechaSesionRepositorio solicitudesCambio) {
		this.sesiones = sesiones;
		this.usuarios = usuarios;
		this.horarios = horarios;
		this.notificationService = notificationService;
		this.solicitudesCambio = solicitudesCambio;
	}

	public List<SesionTutoria> listarDeEstudiante(String estudianteId) {
		return sesiones.findByEstudianteIdsContaining(estudianteId);
	}

	public List<SesionTutoria> listarDeDocente(String docenteId) {
		return sesiones.findByDocenteId(docenteId);
	}

	public List<SesionTutoria> listarPublicadas() {
		LocalDateTime ahora = LocalDateTime.now();
		return sesiones.findAll().stream()
				.filter(sesion -> sesion.fechaInicio().isAfter(ahora))
				.filter(sesion -> sesion.estudianteIds().size() < 5)
				.sorted((left, right) -> left.fechaInicio().compareTo(right.fechaInicio()))
				.toList();
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
		LocalDateTime ahora = LocalDateTime.now();
		if (!sesion.fechaInicio().isAfter(ahora)) {
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
		List<User> coordinadores = usuarios.findAll().stream()
				.filter(user -> user.getRol() != null
						&& user.getRol().toLowerCase(java.util.Locale.ROOT).contains("coordin"))
				.toList();
		if (coordinadores.isEmpty()) {
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
		coordinadores.forEach(coordinador -> notificationService.notifyUser(
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
				if (!nuevoInicio.isAfter(LocalDateTime.now())) {
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

	public List<SesionTutoria> listarDisponibles(String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		String tecnologia = estudiante.getCarrera() == null ? "" : estudiante.getCarrera().trim();
		if (tecnologia.isEmpty()) return List.of();
		return sesiones.findAll().stream()
				.filter(sesion -> sesion.fechaInicio().isAfter(LocalDateTime.now()))
				.filter(sesion -> sesion.estudianteIds().size() < 5)
				.filter(sesion -> !sesion.estudianteIds().contains(estudianteId))
				.filter(sesion -> sesion.tecnologias().stream().anyMatch(tecnologia::equalsIgnoreCase))
				.sorted((left, right) -> left.fechaInicio().compareTo(right.fechaInicio()))
				.toList();
	}

	public List<SesionTutoria> programar(ProgramarTutoriasSolicitud solicitud) {
		if (!CatalogoTecnologias.contiene(solicitud.tecnologia())
				|| solicitud.semestre() < 1 || solicitud.semestre() > 6) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Selecciona una tecnología y semestre válidos.");
		}
		List<SesionTutoria> existentes = sesiones.findAll();
		List<SesionTutoria> nuevas = new ArrayList<>();
		LocalDateTime ahora = LocalDateTime.now();
		for (ProgramarTutoriasSolicitud.Bloque bloque : solicitud.bloques()) {
			if (bloque.modalidad() != ModalidadTutoria.VIRTUAL
					&& (bloque.ubicacion() == null || bloque.ubicacion().isBlank())) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Indica el lugar físico para las tutorías presenciales o híbridas.");
			}
			if (bloque.fechaInicio() == null || bloque.fechaFin() == null
					|| !bloque.fechaFin().isAfter(bloque.fechaInicio())
					|| !bloque.fechaInicio().toLocalDate().equals(bloque.fechaFin().toLocalDate())
					|| !bloque.fechaInicio().isAfter(LocalDateTime.now())) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Cada sesión debe tener una fecha futura y una duración válida.");
			}
			horarios.validarDocenteParaTecnologia(bloque.docenteId(), solicitud.tecnologia(),
					solicitud.semestre(), bloque.materia());
			long tutoriasFuturas = existentes.stream()
					.filter(sesion -> sesion.docenteId().equals(bloque.docenteId()))
					.filter(sesion -> sesion.fechaFin().isAfter(ahora))
					.count()
					+ nuevas.stream()
							.filter(sesion -> sesion.docenteId().equals(bloque.docenteId()))
							.count();
			if (tutoriasFuturas >= 3) {
				throw new ResponseStatusException(HttpStatus.CONFLICT,
						"El docente ya alcanzó el máximo de tres tutorías futuras.");
			}
			boolean conflictoExistente = existentes.stream()
					.anyMatch(sesion -> sesion.docenteId().equals(bloque.docenteId())
							&& bloque.fechaInicio().isBefore(sesion.fechaFin())
							&& sesion.fechaInicio().isBefore(bloque.fechaFin()));
			boolean conflictoNuevo = nuevas.stream()
					.anyMatch(sesion -> sesion.docenteId().equals(bloque.docenteId())
							&& bloque.fechaInicio().isBefore(sesion.fechaFin())
							&& sesion.fechaInicio().isBefore(bloque.fechaFin()));
			if (conflictoExistente || conflictoNuevo) {
				throw new ResponseStatusException(HttpStatus.CONFLICT,
						"El docente ya tiene una tutoría programada en ese horario.");
			}
			nuevas.add(SesionTutoria.crearDisponible(bloque.docenteId(), bloque.fechaInicio(),
					bloque.fechaFin(), bloque.materia(), solicitud.tecnologia(), solicitud.semestre(),
					bloque.modalidad(), bloque.ubicacion() == null ? null : bloque.ubicacion().trim()));
		}
		List<SesionTutoria> guardadas = sesiones.saveAll(nuevas);
		guardadas.forEach(sesion -> notificationService.notifyUser(
				sesion.docenteId(),
				"Nueva tutoría programada",
				"Coordinación programó una tutoría de " + sesion.materia() + " para " + sesion.tecnologia() + ".",
				"/docente"));
		return guardadas;
	}

	public SesionTutoria inscribir(InscripcionTutoriaGrupal solicitud, String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		String tecnologia = estudiante.getCarrera();
		if (tecnologia == null || tecnologia.isBlank()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Completa tu tecnología en el perfil antes de inscribirte.");
		}
		if (solicitud.semestre() < 1 || solicitud.semestre() > 6
				|| !solicitud.fechaFin().isAfter(solicitud.fechaInicio())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Selecciona un semestre y un horario válidos.");
		}
		SesionTutoria existente = sesiones
				.findByDocenteIdAndFechaInicioAndMateriaIgnoreCase(
					solicitud.docenteId(), solicitud.fechaInicio(), solicitud.materia())
				.stream().filter(sesion -> sesion.fechaFin().equals(solicitud.fechaFin()))
				.findFirst().orElse(null);
		if (existente != null) {
			if (existente.estudianteIds().contains(estudianteId)) return existente;
			if (existente.estudianteIds().size() >= 5) {
				throw new ResponseStatusException(HttpStatus.CONFLICT,
						"La sesión grupal ya alcanzó su cupo de cinco estudiantes.");
			}
			SesionTutoria guardada = sesiones.save(existente.inscribir(estudianteId, tecnologia));
			notificarInscripcionGrupal(guardada, estudianteId);
			return guardada;
		}
		horarios.validarDisponibilidad(solicitud.docenteId(), solicitud.modalidad().name(),
				solicitud.fechaInicio(), solicitud.fechaFin());
		horarios.validarMateria(solicitud.docenteId(), estudianteId, solicitud.materia());
		SesionTutoria guardada = sesiones.save(SesionTutoria.crear(solicitud.docenteId(), List.of(estudianteId),
				solicitud.fechaInicio(), solicitud.fechaFin(), solicitud.materia(),
				List.of(tecnologia), tecnologia, solicitud.semestre()));
		notificarInscripcionGrupal(guardada, estudianteId);
		return guardada;
	}

	public void desistir(String sesionId, String estudianteId) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
						"No se encontró la sesión grupal."));
		if (!sesion.estudianteIds().contains(estudianteId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"No estás inscrito en esta sesión.");
		}
		if (sesion.estudianteIds().size() == 1) {
			sesiones.delete(sesion);
		} else {
			sesiones.save(sesion.desistir(estudianteId));
		}
		notificationService.notifyUser(sesion.docenteId(), "Inscripcion grupal cancelada",
				"Un estudiante se retiro de tu sesion de " + sesion.materia() + ".", "/notificaciones");
		notificationService.notifyUser(estudianteId, "Retiro de tutoria confirmado",
				"Te retiraste de la sesion grupal de " + sesion.materia() + ".", "/notificaciones");
	}

	private void notificarInscripcionGrupal(SesionTutoria sesion, String estudianteId) {
		notificationService.notifyUser(sesion.docenteId(), "Nueva inscripcion grupal",
				"Un estudiante se inscribio en tu sesion de " + sesion.materia() + ".", "/notificaciones");
		notificationService.notifyUser(estudianteId, "Inscripcion confirmada",
				"Te inscribiste en la sesion grupal de " + sesion.materia() + ".", "/notificaciones");
	}
	private User buscarEstudiante(String id) {
		return usuarios.findById(id)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
						"No se encontró el estudiante."));
	}
}
