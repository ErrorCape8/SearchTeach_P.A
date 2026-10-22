package com.pa.searchteach.tutorias.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.tutorias.dto.InformeAvanceSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaConAvance;
import com.pa.searchteach.tutorias.dto.ProyectoAulaDisponible;
import com.pa.searchteach.tutorias.dto.ProyectoAulaNombreSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaConAvance;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaEstudiante;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.InformeAvanceProyectoRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.users.repository.UserRepository;
import com.pa.searchteach.users.model.User;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class TutoriasColectivasService {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final InformeAvanceProyectoRepositorio informeRepositorio;
	private final UserRepository userRepository;
	private final NotificationService notificationService;

	public TutoriasColectivasService(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			InformeAvanceProyectoRepositorio informeRepositorio,
			UserRepository userRepository,
			NotificationService notificationService) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.informeRepositorio = informeRepositorio;
		this.userRepository = userRepository;
		this.notificationService = notificationService;
	}

	public TutoriaColectiva crear(TutoriaColectivaSolicitud solicitud, String coordinadoraId) {
		if (!CatalogoTecnologias.contiene(solicitud.tecnologia())) {
			throw new IllegalArgumentException("Selecciona una tecnología del catálogo institucional.");
		}
		List<String> docentes = new ArrayList<>(solicitud.docentesApoyoIds());
		docentes.add(solicitud.docenteLiderId());
		if (docentes.stream().anyMatch(docenteId -> !userRepository.existsById(docenteId))) {
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
		List<String> destinatarios = new ArrayList<>(guardada.docentesApoyoIds());
		destinatarios.add(guardada.docenteLiderId());
		destinatarios.forEach(docenteId -> notificationService.notifyUser(docenteId,
				"Nueva tutoria colectiva asignada",
				"Te asignaron a una tutoria colectiva de " + guardada.tecnologia() + ".", "/notificaciones"));
		return guardada;
	}

	public void eliminar(String tutoriaId) {
		buscarTutoria(tutoriaId);
		informeRepositorio.deleteAll(informeRepositorio.findByTutoriaColectivaId(tutoriaId));
		tutoriaColectivaRepositorio.deleteById(tutoriaId);
	}

	public InformeAvanceProyecto registrarInforme(
			String tutoriaColectivaId,
			String proyectoId,
			InformeAvanceSolicitud solicitud,
			String docenteId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaColectivaId);
		ProyectoAula proyecto = tutoria.proyectos().stream()
				.filter(actual -> actual.proyectoId().equals(proyectoId))
				.findFirst()
				.orElseThrow(() -> new NotFoundException("No se encontró el proyecto del grupo."));
		if (!proyecto.docenteResponsableId().equals(docenteId)) {
			throw new ForbiddenException("Solo el docente de apoyo asignado puede reportar este proyecto.");
		}
		InformeAvanceProyecto informe = new InformeAvanceProyecto(
				UUID.randomUUID().toString(),
				tutoriaColectivaId,
				proyectoId,
				docenteId,
				solicitud.puntajeAvance(),
				solicitud.observaciones(),
				LocalDateTime.now());
		InformeAvanceProyecto guardado = informeRepositorio.save(informe);
		String mensajeInforme = "Se registro un informe para el proyecto " + proyecto.nombre() + ".";
		notificationService.notifyUser(tutoria.coordinadoraId(), "Nuevo informe de avance",
				mensajeInforme, "/notificaciones");
		notificationService.notifyUser(tutoria.docenteLiderId(), "Nuevo informe de avance",
				mensajeInforme, "/notificaciones");
		return guardado;
	}

	public List<TutoriaColectivaConAvance> listarParaLiderPrograma() {
		return tutoriaColectivaRepositorio.findAll().stream()
				.map(tutoria -> new TutoriaColectivaConAvance(
						tutoria,
						tutoria.proyectos().stream()
								.map(proyecto -> {
									List<InformeAvanceProyecto> informes = informeRepositorio
											.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInformeAsc(
													tutoria.id(),
													proyecto.proyectoId());
									return new ProyectoAulaConAvance(
											proyecto,
											informes,
											ModeloMejoraProyecto.evaluar(informes));
								})
								.toList()))
				.toList();
	}

	public List<TutoriaColectiva> listarParaCoordinacion() {
		return tutoriaColectivaRepositorio.findAll();
	}

	public List<TutoriaColectivaEstudiante> listarEspaciosParaEstudiante(String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		return tutoriaColectivaRepositorio.findAll().stream()
				.flatMap(tutoria -> espaciosParaEstudiante(tutoria, estudiante))
				.toList();
	}

	public ProyectoAulaDisponible crearOUnirseAProyecto(
			String tutoriaId,
			ProyectoAulaNombreSolicitud solicitud,
			String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		validarTecnologia(estudiante, tutoria.tecnologia());
		if (tutoria.tecnologia() == null || tutoria.tecnologia().isBlank()
				|| tutoria.semestre() < 1 || tutoria.semestre() > 6) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La tutoría no tiene una carrera y semestre válidos para crear proyectos.");
		}
		String nombre = solicitud.nombre().trim();
		ProyectoAula existente = tutoria.proyectos().stream()
				.filter(proyecto -> proyecto.nombre().trim().equalsIgnoreCase(nombre))
				.findFirst()
				.orElse(null);
		if (existente != null) {
			validarInscripcionUnica(tutoria, estudianteId, existente.proyectoId());
			return inscribirEnProyecto(tutoria, existente, estudianteId);
		}
		validarInscripcionUnica(tutoria, estudianteId, null);
		List<String> docentesApoyo = tutoria.docentesApoyoIds();
		String responsable = docentesApoyo.get(ThreadLocalRandom.current().nextInt(docentesApoyo.size()));
		ProyectoAula proyecto = new ProyectoAula(
				UUID.randomUUID().toString(),
				nombre,
				responsable,
				List.of(estudianteId),
				tutoria.tecnologia(),
				tutoria.semestre());
		TutoriaColectiva actualizado = tutoria.actualizarProyecto(proyecto);
		tutoriaColectivaRepositorio.save(actualizado);
		notificationService.notifyUser(responsable, "Nuevo estudiante en tu proyecto",
				"Un estudiante se unio al proyecto " + proyecto.nombre() + ".", "/notificaciones");
		notificationService.notifyUser(estudianteId, "Proyecto creado",
				"Creaste el proyecto " + proyecto.nombre() + " y quedaste inscrito.", "/notificaciones");
		return disponible(tutoriaId, proyecto, estudianteId);
	}

	public ProyectoAulaDisponible inscribirEstudiante(String tutoriaId, String proyectoId, String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		validarTecnologia(estudiante, proyecto.tecnologia());
		validarInscripcionUnica(tutoria, estudianteId, proyectoId);
		return inscribirEnProyecto(tutoria, proyecto, estudianteId);
	}

	public ProyectoAulaDisponible desistirEstudiante(String tutoriaId, String proyectoId, String estudianteId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		boolean estabaInscrito = proyecto.estudianteIds().contains(estudianteId);
		ProyectoAula actualizado = proyecto.desistir(estudianteId);
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		if (estabaInscrito) {
			notificationService.notifyUser(proyecto.docenteResponsableId(), "Estudiante retiro el proyecto",
					"Un estudiante se retiro del proyecto " + proyecto.nombre() + ".", "/notificaciones");
			notificationService.notifyUser(estudianteId, "Retiro de proyecto confirmado",
					"Te retiraste del proyecto " + proyecto.nombre() + ".", "/notificaciones");
		}
		return disponible(tutoriaId, actualizado, estudianteId);
	}

	public List<InformeAvanceProyecto> listarInformesParaCoordinacion() {
		return informeRepositorio.findAll().stream()
				.sorted((a, b) -> b.fechaInforme().compareTo(a.fechaInforme()))
				.toList();
	}

	public List<ProyectoAsignadoDocente> listarProyectosDeDocente(String docenteId) {
		return tutoriaColectivaRepositorio.findAll().stream()
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.filter(proyecto -> proyecto.docenteResponsableId().equals(docenteId))
						.map(proyecto -> new ProyectoAsignadoDocente(tutoria.id(), proyecto)))
				.toList();
	}

	private TutoriaColectiva buscarTutoria(String id) {
		return tutoriaColectivaRepositorio.findById(id)
				.orElseThrow(() -> new NotFoundException("No se encontró la tutoría colectiva."));
	}

	private ProyectoAula buscarProyecto(TutoriaColectiva tutoria, String proyectoId) {
		return tutoria.proyectos().stream()
				.filter(proyecto -> proyecto.proyectoId().equals(proyectoId))
				.findFirst()
				.orElseThrow(() -> new NotFoundException("No se encontró el espacio de proyecto."));
	}

	private User buscarEstudiante(String id) {
		return userRepository.findById(id)
				.orElseThrow(() -> new NotFoundException("No se encontró el usuario estudiante."));
	}

	private void validarTecnologia(User estudiante, String tecnologia) {
		if (estudiante.getCarrera() == null || estudiante.getCarrera().isBlank()
				|| tecnologia == null || !estudiante.getCarrera().equalsIgnoreCase(tecnologia)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo pueden inscribirse estudiantes de la tecnología del espacio.");
		}
	}

	private void validarInscripcionUnica(TutoriaColectiva tutoria, String estudianteId, String proyectoId) {
		boolean inscritoEnOtroProyecto = tutoria.proyectos().stream()
				.anyMatch(otro -> !otro.proyectoId().equals(proyectoId)
						&& otro.estudianteIds().contains(estudianteId));
		if (inscritoEnOtroProyecto) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Ya estás inscrito en otro proyecto de esta tutoría colectiva.");
		}
	}

	private ProyectoAulaDisponible inscribirEnProyecto(
			TutoriaColectiva tutoria,
			ProyectoAula proyecto,
			String estudianteId) {
		if (proyecto.estudianteIds().size() >= 4 && !proyecto.estudianteIds().contains(estudianteId)) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Este proyecto ya tiene cuatro estudiantes inscritos.");
		}
		ProyectoAula actualizado = proyecto.inscribir(estudianteId);
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		if (!proyecto.estudianteIds().contains(estudianteId)) {
			notificationService.notifyUser(proyecto.docenteResponsableId(), "Nuevo estudiante en tu proyecto",
					"Un estudiante se unio al proyecto " + proyecto.nombre() + ".", "/notificaciones");
			notificationService.notifyUser(estudianteId, "Inscripcion confirmada",
					"Te inscribiste en el proyecto " + proyecto.nombre() + ".", "/notificaciones");
		}
		return disponible(tutoria.id(), actualizado, estudianteId);
	}

	private ProyectoAulaDisponible disponible(String tutoriaId, ProyectoAula proyecto, String estudianteId) {
		return new ProyectoAulaDisponible(tutoriaId, proyecto.proyectoId(), proyecto.nombre(),
				proyecto.docenteResponsableId(), proyecto.tecnologia(), proyecto.semestre(),
				proyecto.estudianteIds().size(), proyecto.estudianteIds().contains(estudianteId));
	}

	private String valor(String texto) {
		return texto == null ? "" : texto.trim();
	}

	private java.util.stream.Stream<TutoriaColectivaEstudiante> espaciosParaEstudiante(
			TutoriaColectiva tutoria,
			User estudiante) {
		String carrera = valor(estudiante.getCarrera());
		if (tutoria.tecnologia() != null) {
			if (!tutoria.tecnologia().equalsIgnoreCase(carrera)) {
				return java.util.stream.Stream.empty();
			}
			return java.util.stream.Stream.of(new TutoriaColectivaEstudiante(
					tutoria.id(),
					tutoria.tecnologia(),
					tutoria.semestre(),
					true,
					tutoria.proyectos().stream()
							.map(proyecto -> disponible(tutoria.id(), proyecto, estudiante.getId()))
							.toList()));
		}
		return tutoria.proyectos().stream()
				.filter(proyecto -> proyecto.tecnologia().equalsIgnoreCase(carrera))
				.collect(java.util.stream.Collectors.groupingBy(
						ProyectoAula::semestre,
						java.util.LinkedHashMap::new,
						java.util.stream.Collectors.toList()))
				.entrySet()
				.stream()
				.map(entry -> new TutoriaColectivaEstudiante(
						tutoria.id(),
						carrera,
						entry.getKey(),
						false,
						entry.getValue().stream()
								.map(proyecto -> disponible(tutoria.id(), proyecto, estudiante.getId()))
								.toList()));
	}
}
