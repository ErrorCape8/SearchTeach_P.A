package com.pa.searchteach.tutorias.service;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;

import com.pa.searchteach.tutorias.dto.InscripcionTutoriaGrupal;
import com.pa.searchteach.tutorias.dto.ProgramarTutoriasSolicitud;
import com.pa.searchteach.tutorias.dto.SolicitudCambioFechaTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.model.AsistenciaEstudiante;
import com.pa.searchteach.tutorias.model.MensajeChatTutoria;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.tutorias.repository.SolicitudCambioFechaSesionRepositorio;
import com.pa.searchteach.tutorias.model.SolicitudCambioFechaSesion;
import com.pa.searchteach.tutorias.dto.ResolverSolicitudCambioFecha;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.scheduling.annotation.Scheduled;

@Service
public class SesionesGrupalesTutoriaService {
	private static final ZoneId ZONA_LOCAL = ZoneId.of("America/Bogota");
	private static final java.util.Set<String> MOTIVOS_CIERRE = java.util.Set.of(
			"FINALIZADA", "FALTA_ESTUDIANTES", "PROBLEMAS_EXTERNOS", "PROBLEMAS_INTERNET", "FINALIZACION_AUTOMATICA");

	private final SesionTutoriaRepositorio sesiones;
	private final UserRepository usuarios;
	private final CoordinatorRepository coordinadores;
	private final HorariosTutoresService horarios;
	private final InscripcionesTutoriasEstudianteService inscripcionesEstudiante;
	private final NotificationService notificationService;
	private final SolicitudCambioFechaSesionRepositorio solicitudesCambio;

	private static LocalDateTime ahora() {
		return LocalDateTime.now(ZONA_LOCAL);
	}

	public SesionesGrupalesTutoriaService(
			SesionTutoriaRepositorio sesiones,
			UserRepository usuarios,
			CoordinatorRepository coordinadores,
			HorariosTutoresService horarios,
			InscripcionesTutoriasEstudianteService inscripcionesEstudiante,
			NotificationService notificationService,
			SolicitudCambioFechaSesionRepositorio solicitudesCambio) {
		this.sesiones = sesiones;
		this.usuarios = usuarios;
		this.coordinadores = coordinadores;
		this.horarios = horarios;
		this.inscripcionesEstudiante = inscripcionesEstudiante;
		this.notificationService = notificationService;
		this.solicitudesCambio = solicitudesCambio;
	}

	public List<SesionTutoria> listarDeEstudiante(String estudianteId) {
		return sesiones.findByEstudianteIdsContaining(estudianteId);
	}

	public List<SesionTutoria> listarDeDocente(String docenteId) {
		return sesiones.findByDocenteId(docenteId).stream().map(this::cerrarSiVencida).toList();
	}

	public SesionTutoria registrarAsistencia(String sesionId, String docenteId, String estudianteId, boolean asistio) {
		SesionTutoria sesion = obtenerSesionDocente(sesionId, docenteId);
		sesion = cerrarSiVencida(sesion);
		if ("FINALIZADA".equals(sesion.estadoClase())) throw new ResponseStatusException(HttpStatus.CONFLICT, "La tutoría ya finalizó.");
		return sesiones.save(sesion.registrarAsistencia(estudianteId, asistio));
	}

	public SesionTutoria cerrarClase(String sesionId, String docenteId, String motivo) {
		SesionTutoria sesion = obtenerSesionDocente(sesionId, docenteId);
		String normalizado = motivo == null ? "" : motivo.trim().toUpperCase(java.util.Locale.ROOT);
		if (!MOTIVOS_CIERRE.contains(normalizado)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona un motivo de cierre válido.");
		return sesiones.save(sesion.cerrar(normalizado, ahora()));
	}

	public SesionTutoria registrarMensaje(String sesionId, String usuarioId, String texto) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.docenteId().equals(usuarioId) && !sesion.estudianteIds().contains(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta tutoría.");
		}
		sesion = cerrarSiVencida(sesion);
		if ("FINALIZADA".equals(sesion.estadoClase())) throw new ResponseStatusException(HttpStatus.CONFLICT, "El chat de esta tutoría ya se cerró.");
		String mensaje = texto == null ? "" : texto.trim();
		if (mensaje.isEmpty() || mensaje.length() > 500) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El mensaje debe tener entre 1 y 500 caracteres.");
		User autor = usuarios.findById(usuarioId).orElse(null);
		return sesiones.save(sesion.agregarMensaje(new MensajeChatTutoria(usuarioId,
				autor == null || autor.getNombre() == null ? usuarioId : autor.getNombre(), mensaje, ahora())));
	}

	private SesionTutoria obtenerSesionDocente(String sesionId, String docenteId) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.docenteId().equals(docenteId)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Solo el docente asignado puede administrar esta tutoría.");
		return sesion;
	}

	private SesionTutoria cerrarSiVencida(SesionTutoria sesion) {
		if (!"FINALIZADA".equals(sesion.estadoClase()) && !ahora().isBefore(sesion.fechaFin())) {
			return sesiones.save(sesion.cerrar("FINALIZACION_AUTOMATICA", sesion.fechaFin()));
		}
		return sesion;
	}

	@Scheduled(fixedDelay = 30000)
	public void finalizarClasesVencidas() {
		LocalDateTime ahora = ahora();
		sesiones.findAll().stream()
				.filter(sesion -> !"FINALIZADA".equals(sesion.estadoClase()))
				.filter(sesion -> !sesion.fechaFin().isAfter(ahora))
				.forEach(sesion -> sesiones.save(sesion.cerrar("FINALIZACION_AUTOMATICA", sesion.fechaFin())));
	}

	public List<SesionTutoria> listarPublicadas() {
		LocalDateTime ahora = ahora();
		return sesiones.findAll().stream()
				.filter(sesion -> sesion.fechaInicio().isAfter(ahora))
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

	public List<SesionTutoria> listarDisponibles(String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		String tecnologia = estudiante.getCarrera() == null ? "" : estudiante.getCarrera().trim();
		if (tecnologia.isEmpty()) return List.of();
		return sesiones.findAll().stream()
				.filter(sesion -> sesion.fechaInicio().isAfter(ahora()))
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
		LocalDateTime ahora = ahora();
		for (ProgramarTutoriasSolicitud.Bloque bloque : solicitud.bloques()) {
			if (bloque.modalidad() != ModalidadTutoria.VIRTUAL
					&& (bloque.ubicacion() == null || bloque.ubicacion().isBlank())) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Indica el lugar físico para las tutorías presenciales o híbridas.");
			}
			if (bloque.fechaInicio() == null || bloque.fechaFin() == null
					|| !bloque.fechaFin().isAfter(bloque.fechaInicio())
					|| !bloque.fechaInicio().toLocalDate().equals(bloque.fechaFin().toLocalDate())
					|| !bloque.fechaInicio().isAfter(ahora)) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"La hora de inicio debe ser futura y la duración debe ser válida.");
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

	public SesionTutoria editarPublicada(String sesionId, ProgramarTutoriasSolicitud solicitud) {
		SesionTutoria actual = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontrÃ³ la tutorÃ­a."));
		if (solicitud.bloques().size() != 1) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Edita una tutorÃ­a a la vez.");
		}
		if (!actual.fechaInicio().isAfter(ahora())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "No puedes editar una tutorÃ­a que ya comenzÃ³.");
		}
		ProgramarTutoriasSolicitud.Bloque bloque = solicitud.bloques().get(0);
		if (!CatalogoTecnologias.contiene(solicitud.tecnologia()) || solicitud.semestre() < 1 || solicitud.semestre() > 6
				|| bloque.fechaInicio() == null || bloque.fechaFin() == null
				|| !bloque.fechaInicio().isAfter(ahora()) || !bloque.fechaFin().isAfter(bloque.fechaInicio())
				|| !bloque.fechaInicio().toLocalDate().equals(bloque.fechaFin().toLocalDate())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona una fecha futura y un horario vÃ¡lido.");
		}
		if (bloque.modalidad() != ModalidadTutoria.VIRTUAL && (bloque.ubicacion() == null || bloque.ubicacion().isBlank())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indica el lugar de la tutorÃ­a.");
		}
		horarios.validarDocenteParaTecnologia(bloque.docenteId(), solicitud.tecnologia(), solicitud.semestre(), bloque.materia());
		boolean conflicto = sesiones.findByDocenteId(bloque.docenteId()).stream()
				.filter(otra -> !otra.id().equals(sesionId))
				.anyMatch(otra -> bloque.fechaInicio().isBefore(otra.fechaFin()) && otra.fechaInicio().isBefore(bloque.fechaFin()));
		if (conflicto) throw new ResponseStatusException(HttpStatus.CONFLICT, "El docente ya tiene una tutorÃ­a en ese horario.");
		for (String estudianteId : actual.estudianteIds()) {
			inscripcionesEstudiante.validarConflictoActual(estudianteId, bloque.fechaInicio(), bloque.fechaFin(), sesionId);
		}
		return sesiones.save(new SesionTutoria(actual.id(), bloque.docenteId(), actual.estudianteIds(),
				bloque.fechaInicio(), bloque.fechaFin(), solicitud.tecnologia(), solicitud.semestre(), actual.asistencias(),
				bloque.materia().trim(), List.of(solicitud.tecnologia()), bloque.modalidad(),
				bloque.ubicacion() == null ? null : bloque.ubicacion().trim()));
	}

	public void eliminarPublicada(String sesionId) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontrÃ³ la tutorÃ­a."));
		sesiones.delete(sesion);
		for (String estudianteId : sesion.estudianteIds()) {
			notificationService.notifyUser(estudianteId, "TutorÃ­a cancelada",
					"La tutorÃ­a de " + sesion.materia() + " fue cancelada por coordinaciÃ³n.", "/estudiante");
		}
		notificationService.notifyUser(sesion.docenteId(), "TutorÃ­a cancelada",
				"La tutorÃ­a de " + sesion.materia() + " fue cancelada por coordinaciÃ³n.", "/docente");
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
			inscripcionesEstudiante.validarNuevaInscripcion(estudianteId,
					existente.fechaInicio(), existente.fechaFin(), existente.id(), null);
			SesionTutoria guardada = sesiones.save(existente.inscribir(estudianteId, tecnologia));
			notificarInscripcionGrupal(guardada, estudianteId);
			return guardada;
		}
		horarios.validarDisponibilidad(solicitud.docenteId(), solicitud.modalidad().name(),
				solicitud.fechaInicio(), solicitud.fechaFin());
		horarios.validarMateria(solicitud.docenteId(), estudianteId, solicitud.materia());
		inscripcionesEstudiante.validarNuevaInscripcion(estudianteId,
				solicitud.fechaInicio(), solicitud.fechaFin(), null, null);
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
