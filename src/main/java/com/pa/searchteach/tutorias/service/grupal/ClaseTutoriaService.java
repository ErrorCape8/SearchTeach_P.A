package com.pa.searchteach.tutorias.service.grupal;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.model.MensajeChatTutoria;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import com.pa.searchteach.tutorias.service.LiveKitRoomAdminService;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import static com.pa.searchteach.tutorias.service.grupal.RelojTutorias.ahora;

/** Ciclo de vida de una clase: iniciar, sala de espera, asistencia, chat, valoración y cierre. */
@Service
public class ClaseTutoriaService {

	private static final java.util.Set<String> MOTIVOS_CIERRE = java.util.Set.of(
			"FINALIZADA", "FALTA_ESTUDIANTES", "PROBLEMAS_EXTERNOS", "PROBLEMAS_INTERNET", "FINALIZACION_AUTOMATICA");
	private static final Duration TTL_AVISO_SALA_ESPERA = Duration.ofMinutes(15);

	private final SesionTutoriaRepositorio sesiones;
	private final UserRepository usuarios;
	private final LiveKitRoomAdminService liveKitRooms;
	private final ActualizacionesTutoriasService actualizacionesTutorias;
	private final CierreSesionesService cierre;
	private final NotificationService notificationService;
	private final ObjectProvider<StringRedisTemplate> redisTemplateProvider;
	private final Map<String, Instant> avisosSalaEsperaLocal = new ConcurrentHashMap<>();

	public ClaseTutoriaService(
			SesionTutoriaRepositorio sesiones,
			UserRepository usuarios,
			LiveKitRoomAdminService liveKitRooms,
			ActualizacionesTutoriasService actualizacionesTutorias,
			CierreSesionesService cierre,
			NotificationService notificationService,
			ObjectProvider<StringRedisTemplate> redisTemplateProvider) {
		this.sesiones = sesiones;
		this.usuarios = usuarios;
		this.liveKitRooms = liveKitRooms;
		this.actualizacionesTutorias = actualizacionesTutorias;
		this.cierre = cierre;
		this.notificationService = notificationService;
		this.redisTemplateProvider = redisTemplateProvider;
	}

	public void notificarEstudianteEnSalaEspera(String sesionId, String estudianteId) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la sesión."));
		if (!sesion.estudianteIds().contains(estudianteId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta sesión.");
		}
		if (!java.util.Set.of(ModalidadTutoria.VIRTUAL, ModalidadTutoria.HIBRIDA).contains(sesion.modalidad())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"La sala de espera solo aplica a tutorías virtuales o híbridas.");
		}
		sesion = cierre.cerrarSiVencida(sesion);
		if ("FINALIZADA".equals(sesion.estadoClase())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "La tutoría ya finalizó.");
		}
		if ("EN_CURSO".equals(sesion.estadoClase())) {
			return;
		}
		if (!registrarPrimerAvisoSalaEspera(sesionId, estudianteId)) {
			return;
		}

		String nombreEstudiante = usuarios.findById(estudianteId)
				.map(User::getNombre)
				.filter(nombre -> nombre != null && !nombre.isBlank())
				.orElse("Un estudiante");
		String materia = resolverNombreMateria(sesion);

		notificationService.notifyUser(
				sesion.docenteId(),
				"Estudiante en sala de espera",
				nombreEstudiante + " está esperando para iniciar la tutoría de " + materia + ".",
				"/docente");
		actualizacionesTutorias.publicar("SALA_ESPERA", sesionId);
	}

	private boolean registrarPrimerAvisoSalaEspera(String sesionId, String estudianteId) {
		String key = "notif:sala_espera:" + sesionId + ":" + estudianteId;
		StringRedisTemplate redis = redisTemplateProvider.getIfAvailable();
		if (redis != null) {
			try {
				Boolean creado = redis.opsForValue().setIfAbsent(key, "1", TTL_AVISO_SALA_ESPERA);
				return Boolean.TRUE.equals(creado);
			} catch (Exception ignored) {
				// Respaldo en memoria si Redis no está disponible
			}
		}
		Instant ahora = Instant.now();
		Instant anterior = avisosSalaEsperaLocal.get(key);
		if (anterior != null && anterior.plus(TTL_AVISO_SALA_ESPERA).isAfter(ahora)) {
			return false;
		}
		avisosSalaEsperaLocal.put(key, ahora);
		return true;
	}

	public SesionTutoria registrarAsistencia(String sesionId, String docenteId, String estudianteId, boolean asistio) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		boolean docenteAsignado = sesion.docenteId().equals(docenteId);
		boolean autoRegistroVirtual = sesion.modalidad() != ModalidadTutoria.PRESENCIAL
				&& docenteId.equals(estudianteId) && asistio
				&& sesion.estudianteIds().contains(estudianteId);
		if (!docenteAsignado && !autoRegistroVirtual) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo el docente o el estudiante conectado pueden registrar su asistencia.");
		}
		sesion = cierre.cerrarSiVencida(sesion);
		if ("FINALIZADA".equals(sesion.estadoClase())) throw new ResponseStatusException(HttpStatus.CONFLICT, "La tutoría ya finalizó.");
		if (!"EN_CURSO".equals(sesion.estadoClase())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El docente debe habilitar la clase antes de registrar asistencia.");
		}
		return sesiones.save(autoRegistroVirtual
				? sesion.registrarEntrada(estudianteId, ahora())
				: sesion.registrarAsistencia(estudianteId, asistio));
	}

	public SesionTutoria cerrarClase(String sesionId, String docenteId, String motivo) {
		SesionTutoria sesion = obtenerSesionDocente(sesionId, docenteId);
		String normalizado = motivo == null ? "" : motivo.trim().toUpperCase(java.util.Locale.ROOT);
		if (!MOTIVOS_CIERRE.contains(normalizado)) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona un motivo de cierre válido.");
		if (sesion.modalidad() == ModalidadTutoria.PRESENCIAL) {
			if (!"EN_CURSO".equals(sesion.estadoClase())) {
				throw new ResponseStatusException(HttpStatus.CONFLICT,
						"Habilita la clase antes de finalizarla.");
			}
			if (!java.util.Set.of("FINALIZADA", "FALTA_ESTUDIANTES").contains(normalizado)) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Para una clase presencial selecciona finalizar la clase o falta de estudiantes.");
			}
			if ("FALTA_ESTUDIANTES".equals(normalizado)
					&& sesion.asistencias().stream().anyMatch(asistencia -> Boolean.TRUE.equals(asistencia.asistio()))) {
				throw new ResponseStatusException(HttpStatus.CONFLICT,
						"No puedes cerrar por falta de estudiantes si registraste a alguien presente.");
			}
		}
		SesionTutoria cerrada = sesiones.save(sesion.cerrar(normalizado, ahora()));
		liveKitRooms.closeGroupTutoringRoom(sesionId);
		actualizacionesTutorias.publicar("FINALIZADA", sesionId);
		return cerrada;
	}

	public SesionTutoria iniciarClase(String sesionId, String docenteId) {
		SesionTutoria sesion = obtenerSesionDocente(sesionId, docenteId);
		if ("FINALIZADA".equals(sesion.estadoClase())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "La tutoría ya finalizó.");
		}
		boolean recienIniciada = !"EN_CURSO".equals(sesion.estadoClase());
		SesionTutoria iniciada = sesiones.save(sesion.iniciar(ahora()));
		actualizacionesTutorias.publicar("EN_CURSO", sesionId);

		if (recienIniciada) {
			String materia = resolverNombreMateria(iniciada);
			String titulo = "Tutoría iniciada";
			String mensaje = "El docente inició la tutoría de " + materia + ". Ya puedes ingresar a la sala.";
			for (String estudianteId : iniciada.estudianteIds()) {
				notificationService.notifyUser(estudianteId, titulo, mensaje, "/estudiante");
			}
		}
		return iniciada;
	}

	public SesionTutoria iniciarClasePresencial(String sesionId, String docenteId) {
		SesionTutoria sesion = obtenerSesionDocente(sesionId, docenteId);
		if (sesion.modalidad() != ModalidadTutoria.PRESENCIAL) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"La habilitacion presencial solo aplica a tutorias presenciales.");
		}
		return iniciarClase(sesionId, docenteId);
	}

	public SesionTutoria valorarClase(String sesionId, String estudianteId, Integer estrellas, String comentario) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.estudianteIds().contains(estudianteId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta tutoría.");
		}
		if (!"FINALIZADA".equals(sesion.estadoClase())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "Solo puedes valorar una tutoría finalizada.");
		}
		if (estrellas == null || estrellas < 1 || estrellas > 5) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "La calificación debe estar entre 1 y 5 estrellas.");
		}
		String texto = comentario == null ? "" : comentario.trim();
		if (texto.length() > 300) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El comentario no puede superar 300 caracteres.");
		}
		SesionTutoria guardada = sesiones.save(sesion.valorar(estudianteId, estrellas, texto, ahora()));
		actualizacionesTutorias.publicar("VALORACION", sesionId);
		return guardada;
	}

	public SesionTutoria registrarMensaje(String sesionId, String usuarioId, String texto) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.docenteId().equals(usuarioId) && !sesion.estudianteIds().contains(usuarioId)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN, "No perteneces a esta tutoría.");
		}
		sesion = cierre.cerrarSiVencida(sesion);
		if ("FINALIZADA".equals(sesion.estadoClase())) throw new ResponseStatusException(HttpStatus.CONFLICT, "El chat de esta tutoría ya se cerró.");
		String mensaje = texto == null ? "" : texto.trim();
		if (mensaje.isEmpty() || mensaje.length() > 500) throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El mensaje debe tener entre 1 y 500 caracteres.");
		User autor = usuarios.findById(usuarioId).orElse(null);
		return sesiones.save(sesion.agregarMensaje(new MensajeChatTutoria(usuarioId,
				autor == null || autor.getNombre() == null ? usuarioId : autor.getNombre(), mensaje, ahora())));
	}

	private String resolverNombreMateria(SesionTutoria sesion) {
		if (sesion.materia() != null && !sesion.materia().isBlank()) {
			return sesion.materia();
		}
		return sesion.tecnologia();
	}

	private SesionTutoria obtenerSesionDocente(String sesionId, String docenteId) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (!sesion.docenteId().equals(docenteId)) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Solo el docente asignado puede administrar esta tutoría.");
		return sesion;
	}
}
