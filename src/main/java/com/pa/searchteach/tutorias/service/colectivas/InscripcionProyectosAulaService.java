package com.pa.searchteach.tutorias.service.colectivas;

import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaCodigoSolicitud;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaCreado;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaDisponible;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaInscripcionPreview;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaNombreSolicitud;
import com.pa.searchteach.tutorias.dto.colectivas.TutoriaColectivaEstudiante;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** Crear proyectos de aula, inscribirse por código y desistir. */
@Service
public class InscripcionProyectosAulaService {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final UserRepository userRepository;
	private final NotificationService notificationService;
	private final ActualizacionesTutoriasService actualizacionesTutoriasService;
	private final BusquedaProyectosAula busqueda;

	public InscripcionProyectosAulaService(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			UserRepository userRepository,
			NotificationService notificationService,
			ActualizacionesTutoriasService actualizacionesTutoriasService,
			BusquedaProyectosAula busqueda) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.userRepository = userRepository;
		this.notificationService = notificationService;
		this.actualizacionesTutoriasService = actualizacionesTutoriasService;
		this.busqueda = busqueda;
	}

	public List<TutoriaColectivaEstudiante> listarEspaciosParaEstudiante(String estudianteId) {
		User estudiante = busqueda.buscarEstudiante(estudianteId);
		List<TutoriaColectiva> tutorias = tutoriaColectivaRepositorio.findAll();
		boolean tieneProyectoActivo = tieneProyectoActivo(tutorias, estudianteId);
		return tutorias.stream()
				.filter(tutoria -> "ACTIVA".equals(tutoria.estado()))
				.flatMap(tutoria -> espaciosParaEstudiante(tutoria, estudiante, tieneProyectoActivo))
				.toList();
	}

	public ProyectoAulaCreado crearProyecto(
			String tutoriaId,
			ProyectoAulaNombreSolicitud solicitud,
			String estudianteId) {
		User estudiante = busqueda.buscarEstudiante(estudianteId);
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		if ("DISUELTA".equals(tutoria.estado())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El grupo de proyectos de aula ya fue disuelto.");
		}
		validarTecnologia(estudiante, tutoria.tecnologia());
		if (tutoria.tecnologia() == null || tutoria.tecnologia().isBlank()
				|| tutoria.semestre() < 1 || tutoria.semestre() > 6) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"La tutoría no tiene una carrera y semestre válidos para crear proyectos.");
		}
		if (solicitud.semestre() != tutoria.semestre()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El semestre ingresado no corresponde al espacio de proyecto seleccionado.");
		}
		String nombre = valor(solicitud.nombre());
		String descripcion = valor(solicitud.descripcion());
		validarInscripcionUnica(estudianteId);
		if (tutoria.proyectos().stream().anyMatch(proyecto -> proyecto.nombre().equals(nombre))) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Ya existe un proyecto con ese título. Escribe otro título para crear el proyecto.");
		}

		List<String> docentesApoyo = tutoria.docentesApoyoIds();
		int menorCarga = docentesApoyo.stream()
				.mapToInt(docenteId -> tutoria.proyectos().stream()
						.filter(proyecto -> proyecto.docenteResponsableId().equals(docenteId))
						.mapToInt(proyecto -> proyecto.estudianteIds().size()).sum())
				.min().orElse(0);
		List<String> menosAsignados = docentesApoyo.stream()
				.filter(docenteId -> tutoria.proyectos().stream()
						.filter(proyecto -> proyecto.docenteResponsableId().equals(docenteId))
						.mapToInt(proyecto -> proyecto.estudianteIds().size()).sum() == menorCarga)
				.toList();
		String responsable = menosAsignados.get(ThreadLocalRandom.current().nextInt(menosAsignados.size()));
		String codigo = generarCodigoInscripcion();
		ProyectoAula proyecto = new ProyectoAula(
				UUID.randomUUID().toString(),
				nombre,
				responsable,
				List.of(estudianteId),
				tutoria.tecnologia(),
				tutoria.semestre(), codigo, "EN_CURSO", null, null, null,
				null, null, null, null, descripcion, null,
				com.pa.searchteach.tutorias.service.grupal.RelojTutorias.ahora());
		TutoriaColectiva actualizado = tutoria.actualizarProyecto(proyecto);
		tutoriaColectivaRepositorio.save(actualizado);
		actualizacionesTutoriasService.publicar("PROYECTO_CAMBIO", tutoriaId);
		notificationService.notifyUser(responsable, "Nuevo estudiante en tu proyecto",
				"Un estudiante se unio al proyecto " + proyecto.nombre() + ".", "/notificaciones");
		notificationService.notifyUser(estudianteId, "Proyecto creado",
				"Creaste el proyecto " + proyecto.nombre() + " y quedaste inscrito.", "/notificaciones");
		return new ProyectoAulaCreado(disponible(tutoriaId, proyecto, estudianteId), codigo);
	}

	public ProyectoAulaInscripcionPreview previsualizarInscripcion(String codigo, String estudianteId) {
		User estudiante = busqueda.buscarEstudiante(estudianteId);
		validarInscripcionUnica(estudianteId);
		ProyectoUbicado ubicado = buscarPorCodigo(codigo);
		validarTecnologia(estudiante, ubicado.proyecto().tecnologia());
		validarProyectoEnCurso(ubicado.proyecto());
		if (ubicado.proyecto().estudianteIds().size() >= 4
				&& !ubicado.proyecto().estudianteIds().contains(estudianteId)) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Este proyecto ya tiene cuatro estudiantes inscritos.");
		}
		String creadorId = ubicado.proyecto().estudianteIds().isEmpty()
				? null : ubicado.proyecto().estudianteIds().get(0);
		String creador = creadorId == null ? "Estudiante"
				: userRepository.findById(creadorId).map(User::getNombre).orElse("Estudiante");
		return new ProyectoAulaInscripcionPreview(ubicado.tutoria().id(), ubicado.proyecto().proyectoId(),
				ubicado.proyecto().nombre(), ubicado.proyecto().descripcion(), creador,
				ubicado.proyecto().tecnologia(), ubicado.proyecto().semestre(),
				ubicado.proyecto().estudianteIds().size());
	}

	public ProyectoAulaDisponible inscribirPorCodigo(ProyectoAulaCodigoSolicitud solicitud, String estudianteId) {
		User estudiante = busqueda.buscarEstudiante(estudianteId);
		validarInscripcionUnica(estudianteId);
		ProyectoUbicado ubicado = buscarPorCodigo(solicitud.codigo());
		validarTecnologia(estudiante, ubicado.proyecto().tecnologia());
		validarProyectoEnCurso(ubicado.proyecto());
		return inscribirEnProyecto(ubicado.tutoria(), ubicado.proyecto(), estudianteId);
	}

	public ProyectoAulaDisponible desistirEstudiante(String tutoriaId, String proyectoId, String estudianteId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		ProyectoAula proyecto = busqueda.buscarProyecto(tutoria, proyectoId);
		validarProyectoEnCurso(proyecto);
		boolean estabaInscrito = proyecto.estudianteIds().contains(estudianteId);
		ProyectoAula actualizado = proyecto.desistir(estudianteId);
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		actualizacionesTutoriasService.publicar("PROYECTO_CAMBIO", tutoriaId);
		if (estabaInscrito) {
			notificationService.notifyUser(proyecto.docenteResponsableId(), "Estudiante retiro el proyecto",
					"Un estudiante se retiro del proyecto " + proyecto.nombre() + ".", "/notificaciones");
			notificationService.notifyUser(estudianteId, "Retiro de proyecto confirmado",
					"Te retiraste del proyecto " + proyecto.nombre() + ".", "/notificaciones");
		}
		return disponible(tutoriaId, actualizado, estudianteId);
	}

	private void validarTecnologia(User estudiante, String tecnologia) {
		if (estudiante.getCarrera() == null || estudiante.getCarrera().isBlank()
				|| tecnologia == null || !estudiante.getCarrera().equalsIgnoreCase(tecnologia)) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo pueden inscribirse estudiantes de la tecnología del espacio.");
		}
	}

	private void validarInscripcionUnica(String estudianteId) {
		if (tieneProyectoActivo(tutoriaColectivaRepositorio.findAll(), estudianteId)) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Ya perteneces a un proyecto de aula activo. No puedes crear otro ni unirte a otro proyecto.");
		}
	}

	private void validarProyectoEnCurso(ProyectoAula proyecto) {
		if (!"EN_CURSO".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El proyecto no está disponible para modificar inscripciones.");
		}
	}

	private boolean tieneProyectoActivo(List<TutoriaColectiva> tutorias, String estudianteId) {
		return tutorias.stream()
				.filter(tutoria -> "ACTIVA".equals(tutoria.estado()))
				.flatMap(tutoria -> tutoria.proyectos().stream())
				.anyMatch(proyecto -> "EN_CURSO".equals(proyecto.estadoCierre())
						&& proyecto.estudianteIds().contains(estudianteId));
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
		actualizacionesTutoriasService.publicar("PROYECTO_CAMBIO", tutoria.id());
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

	private String generarCodigoInscripcion() {
		String codigo;
		boolean existe;
		do {
			codigo = String.format("%06d", ThreadLocalRandom.current().nextInt(1_000_000));
			String candidato = codigo;
			existe = tutoriaColectivaRepositorio.findAll().stream()
					.flatMap(tutoria -> tutoria.proyectos().stream())
					.anyMatch(proyecto -> candidato.equals(proyecto.codigoInscripcion()));
		} while (existe);
		return codigo;
	}

	private ProyectoUbicado buscarPorCodigo(String codigo) {
		if (codigo == null || !codigo.matches("\\d{6}")) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Código incorrecto. Confirma que la tutoría exista o que el código esté bien escrito.");
		}
		return tutoriaColectivaRepositorio.findAll().stream()
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.filter(proyecto -> codigo.equals(proyecto.codigoInscripcion()))
						.map(proyecto -> new ProyectoUbicado(tutoria, proyecto)))
				.findFirst()
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Código incorrecto. Confirma que la tutoría exista o que el código esté bien escrito."));
	}

	private record ProyectoUbicado(TutoriaColectiva tutoria, ProyectoAula proyecto) {}

	private java.util.stream.Stream<TutoriaColectivaEstudiante> espaciosParaEstudiante(
			TutoriaColectiva tutoria,
			User estudiante,
			boolean tieneProyectoActivo) {
		String carrera = valor(estudiante.getCarrera());
		if (tutoria.tecnologia() != null) {
			if (!tutoria.tecnologia().equalsIgnoreCase(carrera)) {
				return java.util.stream.Stream.empty();
			}
			return java.util.stream.Stream.of(new TutoriaColectivaEstudiante(
					tutoria.id(),
					tutoria.tecnologia(),
					tutoria.semestre(),
					!tieneProyectoActivo,
					tutoria.proyectos().stream()
							.filter(proyecto -> "EN_CURSO".equals(proyecto.estadoCierre()))
							.map(proyecto -> disponible(tutoria.id(), proyecto, estudiante.getId()))
							.toList()));
		}
		return tutoria.proyectos().stream()
				.filter(proyecto -> "EN_CURSO".equals(proyecto.estadoCierre())
						&& proyecto.tecnologia().equalsIgnoreCase(carrera))
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
