package com.pa.searchteach.tutorias.service;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.tutorias.dto.InscripcionTutoriaGrupal;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
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

	public SesionesGrupalesTutoriaService(
			SesionTutoriaRepositorio sesiones,
			UserRepository usuarios,
			HorariosTutoresService horarios,
			NotificationService notificationService) {
		this.sesiones = sesiones;
		this.usuarios = usuarios;
		this.horarios = horarios;
		this.notificationService = notificationService;
	}

	public List<SesionTutoria> listarDeEstudiante(String estudianteId) {
		return sesiones.findByEstudianteIdsContaining(estudianteId);
	}

	public List<SesionTutoria> listarDeDocente(String docenteId) {
		return sesiones.findByDocenteId(docenteId);
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
		horarios.validarDisponibilidad(solicitud.docenteId(), solicitud.modalidad().name(),
				solicitud.fechaInicio(), solicitud.fechaFin());
		horarios.validarMateria(solicitud.docenteId(), estudianteId, solicitud.materia());

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
