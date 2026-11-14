package com.pa.searchteach.tutorias.service.grupal;

import java.util.List;

import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.dto.grupal.InscripcionTutoriaGrupal;
import com.pa.searchteach.tutorias.dto.horarios.VentanaHorario;
import com.pa.searchteach.tutorias.model.CatalogoMateriasTecnologia;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import com.pa.searchteach.tutorias.service.HorariosTutoresService;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import static com.pa.searchteach.tutorias.service.grupal.ReglasTutorias.CUPO_MAXIMO_SESION_GRUPAL;
import static com.pa.searchteach.tutorias.service.grupal.ReglasTutorias.semestreValido;

/** Inscripción y retiro de estudiantes en sesiones grupales. */
@Service
public class InscripcionSesionesService {

	private final SesionTutoriaRepositorio sesiones;
	private final UserRepository usuarios;
	private final HorariosTutoresService horarios;
	private final InscripcionesTutoriasEstudianteService inscripcionesEstudiante;
	private final NotificationService notificationService;
	private final ActualizacionesTutoriasService actualizacionesTutorias;

	public InscripcionSesionesService(
			SesionTutoriaRepositorio sesiones,
			UserRepository usuarios,
			HorariosTutoresService horarios,
			InscripcionesTutoriasEstudianteService inscripcionesEstudiante,
			NotificationService notificationService,
			ActualizacionesTutoriasService actualizacionesTutorias) {
		this.sesiones = sesiones;
		this.usuarios = usuarios;
		this.horarios = horarios;
		this.inscripcionesEstudiante = inscripcionesEstudiante;
		this.notificationService = notificationService;
		this.actualizacionesTutorias = actualizacionesTutorias;
	}

	public SesionTutoria inscribir(InscripcionTutoriaGrupal solicitud, String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		String tecnologia = exigirTecnologia(estudiante);
		validarSolicitudInscripcion(solicitud, estudiante);
		SesionTutoria existente = buscarSesionExistente(solicitud);
		if (existente == null) {
			return crearSesionConInscripcion(solicitud, estudianteId, tecnologia);
		}
		return inscribirEnExistente(existente, estudiante, tecnologia);
	}

	private String exigirTecnologia(User estudiante) {
		String tecnologia = estudiante.getCarrera();
		if (tecnologia == null || tecnologia.isBlank()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Completa tu tecnología en el perfil antes de inscribirte.");
		}
		return tecnologia;
	}

	private void validarSolicitudInscripcion(InscripcionTutoriaGrupal solicitud, User estudiante) {
		boolean semestreInvalido = !semestreValido(estudiante.getSemestre())
				|| solicitud.semestre() != estudiante.getSemestre()
				|| !semestreValido(solicitud.semestre());
		if (semestreInvalido || !solicitud.fechaFin().isAfter(solicitud.fechaInicio())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Selecciona un semestre y un horario válidos.");
		}
	}

	private SesionTutoria buscarSesionExistente(InscripcionTutoriaGrupal solicitud) {
		return sesiones
				.findByDocenteIdAndFechaInicioAndMateriaIgnoreCase(
					solicitud.docenteId(), solicitud.fechaInicio(), solicitud.materia())
				.stream().filter(sesion -> sesion.fechaFin().equals(solicitud.fechaFin()))
				.findFirst().orElse(null);
	}

	private SesionTutoria inscribirEnExistente(SesionTutoria existente, User estudiante, String tecnologia) {
		String estudianteId = estudiante.getId();
		boolean ofreceTecnologia = existente.tecnologias().stream().anyMatch(
				oferta -> CatalogoMateriasTecnologia.normalizar(oferta).equals(CatalogoMateriasTecnologia.normalizar(tecnologia)));
		if (existente.semestre() != estudiante.getSemestre() || !ofreceTecnologia) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La tutoría no corresponde a tu tecnología y semestre.");
		}
		if (existente.estudianteIds().contains(estudianteId)) return existente;
		if (existente.estudianteIds().size() >= CUPO_MAXIMO_SESION_GRUPAL) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La sesión grupal ya alcanzó su cupo de cinco estudiantes.");
		}
		inscripcionesEstudiante.validarNuevaInscripcion(estudianteId,
				new VentanaHorario(existente.fechaInicio(), existente.fechaFin()), existente.id());
		return guardarInscripcion(sesiones.save(existente.inscribir(estudianteId, tecnologia)), estudianteId);
	}

	private SesionTutoria crearSesionConInscripcion(
			InscripcionTutoriaGrupal solicitud, String estudianteId, String tecnologia) {
		horarios.validarDisponibilidad(solicitud.docenteId(), solicitud.modalidad().name(),
				solicitud.fechaInicio(), solicitud.fechaFin());
		horarios.validarMateria(solicitud.docenteId(), estudianteId, solicitud.materia());
		inscripcionesEstudiante.validarNuevaInscripcion(estudianteId,
				new VentanaHorario(solicitud.fechaInicio(), solicitud.fechaFin()), null);
		SesionTutoria nueva = sesiones.save(SesionTutoria.crear(solicitud.docenteId(), List.of(estudianteId),
				solicitud.fechaInicio(), solicitud.fechaFin(), solicitud.materia(),
				List.of(tecnologia), tecnologia, solicitud.semestre()));
		return guardarInscripcion(nueva, estudianteId);
	}

	private SesionTutoria guardarInscripcion(SesionTutoria guardada, String estudianteId) {
		actualizacionesTutorias.publicar("INSCRIPCION", guardada.id());
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
			actualizacionesTutorias.publicar("RETIRO", sesionId);
		} else {
			sesiones.save(sesion.desistir(estudianteId));
			actualizacionesTutorias.publicar("RETIRO", sesionId);
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
