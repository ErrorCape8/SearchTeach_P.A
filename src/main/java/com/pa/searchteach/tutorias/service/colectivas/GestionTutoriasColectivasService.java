package com.pa.searchteach.tutorias.service.colectivas;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.dto.colectivas.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.InformeAvanceProyectoRepositorio;
import com.pa.searchteach.tutorias.repository.MensajeProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.RespuestaReunionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.SesionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** Crear, actualizar, eliminar y disolver las tutorías colectivas (coordinación). */
@Service
public class GestionTutoriasColectivasService {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final InformeAvanceProyectoRepositorio informeRepositorio;
	private final SesionProyectoAulaRepositorio sesionProyectoRepositorio;
	private final MensajeProyectoAulaRepositorio mensajeProyectoRepositorio;
	private final RespuestaReunionProyectoAulaRepositorio reunionRepositorio;
	private final UserRepository userRepository;
	private final NotificationService notificationService;
	private final ActualizacionesTutoriasService actualizacionesTutoriasService;
	private final BusquedaProyectosAula busqueda;

	public GestionTutoriasColectivasService(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			InformeAvanceProyectoRepositorio informeRepositorio,
			SesionProyectoAulaRepositorio sesionProyectoRepositorio,
			MensajeProyectoAulaRepositorio mensajeProyectoRepositorio,
			RespuestaReunionProyectoAulaRepositorio reunionRepositorio,
			UserRepository userRepository,
			NotificationService notificationService,
			ActualizacionesTutoriasService actualizacionesTutoriasService,
			BusquedaProyectosAula busqueda) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.informeRepositorio = informeRepositorio;
		this.sesionProyectoRepositorio = sesionProyectoRepositorio;
		this.mensajeProyectoRepositorio = mensajeProyectoRepositorio;
		this.reunionRepositorio = reunionRepositorio;
		this.userRepository = userRepository;
		this.notificationService = notificationService;
		this.actualizacionesTutoriasService = actualizacionesTutoriasService;
		this.busqueda = busqueda;
	}

	public TutoriaColectiva crear(TutoriaColectivaSolicitud solicitud, String coordinadoraId) {
		if (!CatalogoTecnologias.contiene(solicitud.tecnologia())) {
			throw new IllegalArgumentException("Selecciona una tecnología del catálogo institucional.");
		}
		List<String> docentes = new ArrayList<>(solicitud.docentesApoyoIds());
		docentes.add(solicitud.docenteLiderId());
		if (docentes.stream().anyMatch(docenteId -> userRepository.findById(docenteId)
				.filter(this::esDocenteActivoDeTecnologia)
				.filter(user -> user.getCarrera() != null
						&& user.getCarrera().equalsIgnoreCase(solicitud.tecnologia().trim()))
				.isEmpty())) {
			throw new IllegalArgumentException(
					"El docente líder y los docentes de apoyo deben tener una cuenta registrada.");
		}
		TutoriaColectiva tutoriaColectiva = new TutoriaColectiva(
				null,
				coordinadoraId,
				solicitud.docenteLiderId(),
				solicitud.docentesApoyoIds(),
				solicitud.tecnologia().trim(),
				solicitud.semestre(),
				List.of(),
				LocalDateTime.now());
		TutoriaColectiva guardada = tutoriaColectivaRepositorio.save(tutoriaColectiva);
		actualizacionesTutoriasService.publicar("TUTORIA_COLECTIVA_CAMBIO", guardada.id());
		List<String> destinatarios = new ArrayList<>(guardada.docentesApoyoIds());
		destinatarios.add(guardada.docenteLiderId());
		destinatarios.forEach(docenteId -> notificationService.notifyUser(docenteId,
				"Nueva tutoria colectiva asignada",
				"Te asignaron a una tutoria colectiva de " + guardada.tecnologia() + ".", "/notificaciones"));
		return guardada;
	}

	public TutoriaColectiva actualizar(String tutoriaId, TutoriaColectivaSolicitud solicitud) {
		TutoriaColectiva actual = busqueda.buscarTutoria(tutoriaId);
		if ("DISUELTA".equals(actual.estado())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La tutoría colectiva está disuelta y solo puede consultarse.");
		}
		if (!CatalogoTecnologias.contiene(solicitud.tecnologia())) {
			throw new IllegalArgumentException("Selecciona una tecnología del catálogo institucional.");
		}
		validarDocentesAsignados(solicitud);
		List<String> docentesAsignados = new ArrayList<>(solicitud.docentesApoyoIds());
		docentesAsignados.add(solicitud.docenteLiderId());
		boolean cambiaTecnologiaOSemestre = !actual.tecnologia().equalsIgnoreCase(solicitud.tecnologia().trim())
				|| actual.semestre() != solicitud.semestre();
		if (!actual.proyectos().isEmpty() && cambiaTecnologiaOSemestre) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"No puedes cambiar tecnología o semestre mientras haya proyectos inscritos.");
		}
		if (actual.proyectos().stream()
				.anyMatch(proyecto -> !docentesAsignados.contains(proyecto.docenteResponsableId()))) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Conserva asignados a los docentes que ya tienen proyectos a cargo.");
		}
		TutoriaColectiva guardada = tutoriaColectivaRepositorio.save(new TutoriaColectiva(
				actual.id(), actual.coordinadoraId(), solicitud.docenteLiderId(), solicitud.docentesApoyoIds(),
				solicitud.tecnologia().trim(), solicitud.semestre(), actual.proyectos(), actual.creadaEn()));
		actualizacionesTutoriasService.publicar("TUTORIA_COLECTIVA_CAMBIO", guardada.id());
		return guardada;
	}

	private void validarDocentesAsignados(TutoriaColectivaSolicitud solicitud) {
		List<String> docentes = new ArrayList<>(solicitud.docentesApoyoIds());
		docentes.add(solicitud.docenteLiderId());
		if (docentes.stream().anyMatch(docenteId -> userRepository.findById(docenteId)
				.filter(this::esDocenteActivoDeTecnologia)
				.filter(user -> user.getCarrera() != null
						&& user.getCarrera().equalsIgnoreCase(solicitud.tecnologia().trim()))
				.isEmpty())) {
			throw new IllegalArgumentException("Selecciona docentes activos asignados a la tecnología elegida.");
		}
	}

	public void eliminar(String tutoriaId, String confirmacion) {
		if (!"eliminar".equals(confirmacion == null ? "" : confirmacion.trim().toLowerCase(Locale.ROOT))) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Escribe 'eliminar' para confirmar la eliminación.");
		}
		busqueda.buscarTutoria(tutoriaId);
		informeRepositorio.deleteAll(informeRepositorio.findByTutoriaColectivaId(tutoriaId));
		sesionProyectoRepositorio.deleteByTutoriaColectivaId(tutoriaId);
		mensajeProyectoRepositorio.deleteByTutoriaColectivaId(tutoriaId);
		reunionRepositorio.deleteByTutoriaColectivaId(tutoriaId);
		tutoriaColectivaRepositorio.deleteById(tutoriaId);
		actualizacionesTutoriasService.publicar("TUTORIA_COLECTIVA_CAMBIO", tutoriaId);
	}

	public TutoriaColectiva disolver(String tutoriaId, String confirmacion) {
		if (!"disolver".equals(confirmacion == null ? "" : confirmacion.trim().toLowerCase(Locale.ROOT))) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Escribe 'disolver' para confirmar la disolución.");
		}
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		if ("DISUELTA".equals(tutoria.estado())) return tutoria;
		TutoriaColectiva disuelta = tutoria.disolver();
		tutoriaColectivaRepositorio.save(disuelta);
		actualizacionesTutoriasService.publicar("TUTORIA_COLECTIVA_CAMBIO", tutoriaId);
		tutoria.proyectos().stream()
				.flatMap(proyecto -> proyecto.estudianteIds().stream())
				.distinct()
				.forEach(estudianteId -> notificationService.notifyUser(
						estudianteId,
						"Proyecto de aula disuelto",
						"El grupo de proyecto de aula fue disuelto por coordinación. "
								+ "Ya no está disponible para continuar.",
						"/notificaciones"));
		notificationService.notifyUser(tutoria.docenteLiderId(), "Grupo de proyecto disuelto",
				"El grupo fue archivado por coordinación. El historial se conserva para consulta.", "/notificaciones");
		tutoria.docentesApoyoIds().forEach(docenteId -> notificationService.notifyUser(
				docenteId, "Grupo de proyecto disuelto",
				"El grupo fue archivado por coordinación. El historial se conserva para consulta.", "/notificaciones"));
		return disuelta;
	}

	private boolean esDocenteActivoDeTecnologia(User user) {
		return user.getRol() != null && user.getRol().toLowerCase(java.util.Locale.ROOT).contains("docente")
				&& (user.getEstado() == null || user.getEstado().isBlank()
						|| "Activo".equalsIgnoreCase(user.getEstado()));
	}

	public List<TutoriaColectiva> listarParaLiderPrograma() {
		return tutoriaColectivaRepositorio.findAll();
	}

	public List<TutoriaColectiva> listarParaCoordinacion() {
		return tutoriaColectivaRepositorio.findAll();
	}
}
