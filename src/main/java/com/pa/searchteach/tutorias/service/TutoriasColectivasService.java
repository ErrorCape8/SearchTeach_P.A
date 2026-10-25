package com.pa.searchteach.tutorias.service;

import java.time.LocalDateTime;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;
import java.util.Locale;
import java.util.zip.ZipInputStream;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.tutorias.dto.InformeAvanceSolicitud;
import com.pa.searchteach.tutorias.dto.SesionProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.ReunionProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaSeguimientoEstudiante;
import com.pa.searchteach.tutorias.dto.MensajeProyectoAulaVista;
import com.pa.searchteach.tutorias.dto.ProyectoAulaDisponible;
import com.pa.searchteach.tutorias.dto.ProyectoAulaCreado;
import com.pa.searchteach.tutorias.dto.ProyectoAulaCodigoSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaInscripcionPreview;
import com.pa.searchteach.tutorias.dto.ProyectoAulaNombreSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaEstudiante;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.SesionProyectoAula;
import com.pa.searchteach.tutorias.model.MensajeProyectoAula;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.InformeAvanceProyectoRepositorio;
import com.pa.searchteach.tutorias.repository.SesionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.MensajeProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.users.repository.UserRepository;
import com.pa.searchteach.users.model.User;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.scheduling.annotation.Scheduled;

@Service
public class TutoriasColectivasService {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final InformeAvanceProyectoRepositorio informeRepositorio;
	private final SesionProyectoAulaRepositorio sesionProyectoRepositorio;
	private final MensajeProyectoAulaRepositorio mensajeProyectoRepositorio;
	private final UserRepository userRepository;
	private final NotificationService notificationService;

	public TutoriasColectivasService(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			InformeAvanceProyectoRepositorio informeRepositorio,
			SesionProyectoAulaRepositorio sesionProyectoRepositorio,
			MensajeProyectoAulaRepositorio mensajeProyectoRepositorio,
			UserRepository userRepository,
			NotificationService notificationService) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.informeRepositorio = informeRepositorio;
		this.sesionProyectoRepositorio = sesionProyectoRepositorio;
		this.mensajeProyectoRepositorio = mensajeProyectoRepositorio;
		this.userRepository = userRepository;
		this.notificationService = notificationService;
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
		List<String> destinatarios = new ArrayList<>(guardada.docentesApoyoIds());
		destinatarios.add(guardada.docenteLiderId());
		destinatarios.forEach(docenteId -> notificationService.notifyUser(docenteId,
				"Nueva tutoria colectiva asignada",
				"Te asignaron a una tutoria colectiva de " + guardada.tecnologia() + ".", "/notificaciones"));
		return guardada;
	}

	public TutoriaColectiva actualizar(String tutoriaId, TutoriaColectivaSolicitud solicitud) {
		TutoriaColectiva actual = buscarTutoria(tutoriaId);
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
		return tutoriaColectivaRepositorio.save(new TutoriaColectiva(
				actual.id(), actual.coordinadoraId(), solicitud.docenteLiderId(), solicitud.docentesApoyoIds(),
				solicitud.tecnologia().trim(), solicitud.semestre(), actual.proyectos(), actual.creadaEn()));
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

	public void eliminar(String tutoriaId) {
		buscarTutoria(tutoriaId);
		informeRepositorio.deleteAll(informeRepositorio.findByTutoriaColectivaId(tutoriaId));
		sesionProyectoRepositorio.deleteByTutoriaColectivaId(tutoriaId);
		mensajeProyectoRepositorio.deleteByTutoriaColectivaId(tutoriaId);
		tutoriaColectivaRepositorio.deleteById(tutoriaId);
	}

	public List<ProyectoAulaSeguimientoEstudiante> listarSeguimientoEstudiante(String estudianteId) {
		return tutoriaColectivaRepositorio.findAll().stream()
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.filter(proyecto -> proyecto.estudianteIds().contains(estudianteId))
						.map(proyecto -> new ProyectoAulaSeguimientoEstudiante(
								tutoria.id(), proyecto,
								sesionProyectoRepositorio.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInicioDesc(
										tutoria.id(), proyecto.proyectoId()))))
				.toList();
	}

	public SesionProyectoAula registrarSesionProyecto(
			String tutoriaId, String proyectoId, SesionProyectoAulaSolicitud solicitud, String docenteId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		if (!proyecto.docenteResponsableId().equals(docenteId)) {
			throw new ForbiddenException("Solo el tutor asignado a este proyecto puede registrar sus sesiones.");
		}
		if ("FINALIZADO".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "No puedes agregar sesiones a un proyecto finalizado.");
		}
		SesionProyectoAula sesion = new SesionProyectoAula(
				UUID.randomUUID().toString(), tutoriaId, proyectoId, docenteId,
				solicitud.fechaInicio(), solicitud.fechaFin(), solicitud.contenido().trim(), LocalDateTime.now());
		SesionProyectoAula guardada = sesionProyectoRepositorio.save(sesion);
		notificationService.notifyUser(tutoria.docenteLiderId(), "Nuevo reporte de proyecto de aula",
				"El tutor de apoyo registró un reporte para " + proyecto.nombre() + ". Revísalo en el panel docente.",
				"/docente");
		proyecto.estudianteIds().forEach(estudianteId -> notificationService.notifyUser(
				estudianteId, "Nuevo seguimiento de proyecto",
				"El tutor actualizó el horario y las notas de " + proyecto.nombre() + ".", "/notificaciones"));
		return guardada;
	}

	public SesionProyectoAula confirmarReporteProyecto(
			String tutoriaId, String proyectoId, String sesionId, String docenteLiderId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		if (!tutoria.docenteLiderId().equals(docenteLiderId)) {
			throw new ForbiddenException("Solo el docente líder puede confirmar un reporte de apoyo.");
		}
		buscarProyecto(tutoria, proyectoId);
		SesionProyectoAula sesion = sesionProyectoRepositorio
				.findByIdAndTutoriaColectivaIdAndProyectoId(sesionId, tutoriaId, proyectoId)
				.orElseThrow(() -> new NotFoundException("No se encontró el reporte del proyecto."));
		if (sesion.confirmadoPorLiderId() != null) return sesion;
		SesionProyectoAula confirmada = sesion.confirmar(docenteLiderId, LocalDateTime.now());
		sesionProyectoRepositorio.save(confirmada);
		notificationService.notifyUser(sesion.docenteId(), "Reporte de apoyo confirmado",
				"El docente líder confirmó el reporte registrado para el proyecto.", "/docente");
		return confirmada;
	}

	public List<SesionProyectoAula> listarSesionesProyectoDocente(
			String tutoriaId, String proyectoId, String docenteId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		if (!proyecto.docenteResponsableId().equals(docenteId) && !tutoria.docenteLiderId().equals(docenteId)) {
			throw new ForbiddenException("Solo el tutor asignado y el docente líder pueden consultar este reporte.");
		}
		return sesionProyectoRepositorio.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInicioDesc(
				tutoriaId, proyectoId);
	}

	public List<ProyectoAsignadoDocente> listarProyectosParaLider(String docenteLiderId) {
		return tutoriaColectivaRepositorio.findAll().stream()
				.filter(tutoria -> tutoria.docenteLiderId().equals(docenteLiderId))
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.map(proyecto -> new ProyectoAsignadoDocente(tutoria.id(), proyecto)))
				.toList();
	}

	public ProyectoAula obtenerProyectoEnChat(String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		validarAccesoProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		return buscarProyecto(buscarTutoria(tutoriaId), proyectoId);
	}

	public ProyectoAula programarReunionProyecto(
			String tutoriaId, String proyectoId, String sesionId,
			ReunionProyectoAulaSolicitud solicitud, String docenteId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		validarTutorResponsable(proyecto, docenteId);
		if ("FINALIZADO".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "El proyecto ya fue finalizado.");
		}
		sesionProyectoRepositorio.findByIdAndTutoriaColectivaIdAndProyectoId(sesionId, tutoriaId, proyectoId)
				.orElseThrow(() -> new NotFoundException("No se encontró el reporte asociado a este chat."));
		ProyectoAula actualizado = proyecto.programarReunion(solicitud.fechaReunion(), docenteId, sesionId);
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		String fecha = solicitud.fechaReunion().toString().replace('T', ' ');
		java.util.stream.Stream.concat(proyecto.estudianteIds().stream(), java.util.stream.Stream.of(tutoria.docenteLiderId()))
				.distinct().forEach(destinatario -> notificationService.notifyUser(destinatario,
						"Reunión de proyecto de aula programada",
						"El tutor programó una reunión para " + proyecto.nombre() + " el " + fecha + ".",
						"/notificaciones"));
		return actualizado;
	}

	@Scheduled(fixedDelay = 30000)
	public void publicarAvisosDeReunionesIniciadas() {
		LocalDateTime ahora = LocalDateTime.now();
		for (TutoriaColectiva tutoria : tutoriaColectivaRepositorio.findAll()) {
			TutoriaColectiva actual = tutoria;
			for (ProyectoAula proyecto : tutoria.proyectos()) {
				if (proyecto.fechaReunion() == null || proyecto.fechaReunion().isAfter(ahora)
						|| proyecto.reunionMensajePublicadoEn() != null || proyecto.reunionSesionId() == null) continue;
				if (sesionProyectoRepositorio.findByIdAndTutoriaColectivaIdAndProyectoId(
						proyecto.reunionSesionId(), tutoria.id(), proyecto.proyectoId()).isEmpty()) continue;
				String roomId = "searchteach-pa-" + proyecto.proyectoId();
				mensajeProyectoRepositorio.save(new MensajeProyectoAula(
						UUID.randomUUID().toString(), tutoria.id(), proyecto.proyectoId(),
						proyecto.reunionSesionId(), proyecto.docenteResponsableId(),
						"La reunión de proyecto de aula está comenzando. Entra a la sala desde este mensaje.",
						null, null, null, null, ahora, "REUNION", roomId));
				ProyectoAula actualizado = proyecto.marcarMensajeReunionPublicado(ahora);
				actual = actual.actualizarProyecto(actualizado);
				tutoriaColectivaRepositorio.save(actual);
				java.util.stream.Stream.concat(proyecto.estudianteIds().stream(),
						java.util.stream.Stream.of(tutoria.docenteLiderId(), proyecto.docenteResponsableId()))
						.distinct().forEach(destinatario -> notificationService.notifyUser(destinatario,
								"La reunión de proyecto de aula comenzó",
								"Entra al chat de " + proyecto.nombre() + " para unirte a la reunión.",
								"/notificaciones"));
			}
		}
	}

	public ProyectoAula solicitarCierreProyecto(
			String tutoriaId, String proyectoId, String motivo, String docenteId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		validarTutorResponsable(proyecto, docenteId);
		String motivoNormalizado = motivo == null ? "" : motivo.trim().toUpperCase(Locale.ROOT);
		if (!List.of("LISTO", "SIN_ATENCION").contains(motivoNormalizado)) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona un motivo válido para finalizar el proyecto.");
		}
		if (!"EN_CURSO".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "El proyecto no está disponible para solicitar cierre.");
		}
		ProyectoAula actualizado = proyecto.solicitarCierre(motivoNormalizado);
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		notificationService.notifyUser(tutoria.docenteLiderId(), "Proyecto pendiente de confirmación",
				"El tutor solicitó finalizar " + proyecto.nombre() + ". Revisa el reporte y confirma el cierre.",
				"/docente");
		return actualizado;
	}

	public ProyectoAula responderSolicitudCierre(
			String tutoriaId, String proyectoId, boolean confirmar, String docenteLiderId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		if (!tutoria.docenteLiderId().equals(docenteLiderId)) {
			throw new ForbiddenException("Solo el docente líder puede confirmar el cierre del proyecto.");
		}
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		if (!"PENDIENTE_CONFIRMACION".equals(proyecto.estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "No hay una solicitud de cierre pendiente.");
		}
		List<SesionProyectoAula> reportes = sesionProyectoRepositorio
				.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInicioDesc(tutoriaId, proyectoId);
		if (confirmar && (reportes.isEmpty()
				|| reportes.stream().anyMatch(sesion -> sesion.confirmadoPorLiderId() == null))) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Debe haber reportes de sesión y el docente líder debe confirmarlos antes de finalizar el proyecto.");
		}
		ProyectoAula actualizado = confirmar
				? proyecto.confirmarCierre(docenteLiderId, LocalDateTime.now())
				: proyecto.rechazarCierre();
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
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

	private void validarTutorResponsable(ProyectoAula proyecto, String docenteId) {
		if (!proyecto.docenteResponsableId().equals(docenteId)) {
			throw new ForbiddenException("Solo el docente de apoyo asignado puede gestionar este proyecto.");
		}
	}

	public List<MensajeProyectoAulaVista> listarMensajesProyecto(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		validarAccesoProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		return mensajeProyectoRepositorio
				.findByTutoriaColectivaIdAndProyectoIdAndSesionIdOrderByEnviadoEnAsc(
						tutoriaId, proyectoId, sesionId)
				.stream()
				.map(mensaje -> new MensajeProyectoAulaVista(
						mensaje.id(), mensaje.emisorId(), mensaje.emisorId().equals(usuarioId),
						mensaje.texto(), mensaje.archivoNombre(), mensaje.archivoMime(),
						mensaje.archivoTamano(), mensaje.enviadoEn(), mensaje.tipo(), mensaje.reunionRoomId()))
				.toList();
	}

	public MensajeProyectoAulaVista registrarMensajeProyecto(
			String tutoriaId, String proyectoId, String sesionId, String usuarioId,
			String texto, MultipartFile archivo) {
		validarAccesoProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		if ("FINALIZADO".equals(buscarProyecto(buscarTutoria(tutoriaId), proyectoId).estadoCierre())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "El chat quedó cerrado al finalizar el proyecto.");
		}
		String contenido = texto == null ? "" : texto.trim();
		if (contenido.length() > 4000 || (contenido.isEmpty() && (archivo == null || archivo.isEmpty()))) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Escribe un mensaje o adjunta un archivo; el texto admite hasta 4000 caracteres.");
		}
		byte[] bytes = null;
		String nombre = null;
		String mime = null;
		if (archivo != null && !archivo.isEmpty()) {
			try {
				bytes = archivo.getBytes();
			} catch (IOException error) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "No se pudo leer el archivo adjunto.");
			}
			if (bytes.length > 8 * 1024 * 1024) {
				throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "El archivo no puede superar 8 MB.");
			}
			String original = archivo.getOriginalFilename() == null ? "" : archivo.getOriginalFilename();
			nombre = original.replace('\\', '/');
			nombre = nombre.substring(nombre.lastIndexOf('/') + 1).replaceAll("[^A-Za-z0-9._ -]", "_");
			String extension = nombre.substring(nombre.lastIndexOf('.') + 1).toLowerCase(Locale.ROOT);
			mime = switch (extension) {
				case "pdf" -> "application/pdf";
				case "docx" -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
				default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Solo se permiten archivos PDF o Word (.docx).");
			};
			if (!archivoValido(extension, bytes)) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"El contenido del archivo no coincide con su tipo permitido.");
			}
		}
		MensajeProyectoAula guardado = mensajeProyectoRepositorio.save(new MensajeProyectoAula(
				UUID.randomUUID().toString(), tutoriaId, proyectoId, sesionId, usuarioId,
				contenido, nombre, mime, bytes == null ? null : (long) bytes.length, bytes, LocalDateTime.now()));
		return new MensajeProyectoAulaVista(guardado.id(), guardado.emisorId(), true, guardado.texto(),
				guardado.archivoNombre(), guardado.archivoMime(), guardado.archivoTamano(), guardado.enviadoEn(),
				guardado.tipo(), guardado.reunionRoomId());
	}

	public MensajeProyectoAula descargarArchivoProyecto(
			String tutoriaId, String proyectoId, String sesionId, String mensajeId, String usuarioId) {
		validarAccesoProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
		return mensajeProyectoRepositorio
				.findByTutoriaColectivaIdAndProyectoIdAndSesionIdOrderByEnviadoEnAsc(
						tutoriaId, proyectoId, sesionId).stream()
				.filter(mensaje -> mensaje.id().equals(mensajeId) && mensaje.archivoContenido() != null)
				.findFirst()
				.orElseThrow(() -> new NotFoundException("No se encontró el archivo adjunto."));
	}

	private void validarAccesoProyecto(String tutoriaId, String proyectoId, String sesionId, String usuarioId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		if (!proyecto.docenteResponsableId().equals(usuarioId) && !proyecto.estudianteIds().contains(usuarioId)
				&& !tutoria.docenteLiderId().equals(usuarioId)) {
			throw new ForbiddenException("Solo el tutor asignado, el docente líder y los estudiantes inscritos pueden acceder al reporte.");
		}
		sesionProyectoRepositorio.findByIdAndTutoriaColectivaIdAndProyectoId(sesionId, tutoriaId, proyectoId)
				.orElseThrow(() -> new NotFoundException("No se encontró el reporte del proyecto."));
	}

	private boolean archivoValido(String extension, byte[] bytes) {
		if ("pdf".equals(extension)) {
			return bytes.length >= 5 && bytes[0] == '%' && bytes[1] == 'P'
					&& bytes[2] == 'D' && bytes[3] == 'F' && bytes[4] == '-';
		}
		if (!"docx".equals(extension) || bytes.length < 4 || bytes[0] != 'P' || bytes[1] != 'K') return false;
		boolean document = false;
		boolean contentTypes = false;
		boolean macroProject = false;
		long uncompressedBytes = 0;
		try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(bytes))) {
			java.util.zip.ZipEntry entry;
			byte[] buffer = new byte[4096];
			while ((entry = zip.getNextEntry()) != null) {
				if ("word/document.xml".equals(entry.getName())) document = true;
				if ("[Content_Types].xml".equals(entry.getName())) contentTypes = true;
				if ("word/vbaProject.bin".equalsIgnoreCase(entry.getName())) macroProject = true;
				int read;
				while ((read = zip.read(buffer)) != -1) {
					uncompressedBytes += read;
					if (uncompressedBytes > 24L * 1024 * 1024) return false;
				}
			}
		} catch (IOException error) {
			return false;
		}
		return document && contentTypes && !macroProject;
	}

	public List<TutoriaColectiva> listarParaLiderPrograma() {
		return tutoriaColectivaRepositorio.findAll();
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

	public ProyectoAulaCreado crearOUnirseAProyecto(
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
		if (solicitud.semestre() != tutoria.semestre()) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El semestre ingresado no corresponde al espacio de proyecto seleccionado.");
		}
		validarInscripcionUnica(tutoria, estudianteId, null);
		List<ProyectoAula> gruposConCupo = tutoria.proyectos().stream()
				.filter(proyecto -> proyecto.estudianteIds().size() < 4
						&& "EN_CURSO".equals(proyecto.estadoCierre()))
				.toList();
		if (!gruposConCupo.isEmpty()) {
			int menorTamano = gruposConCupo.stream().mapToInt(proyecto -> proyecto.estudianteIds().size()).min().orElse(0);
			List<ProyectoAula> menosLlenos = gruposConCupo.stream()
					.filter(proyecto -> proyecto.estudianteIds().size() == menorTamano).toList();
			ProyectoAula asignado = menosLlenos.get(ThreadLocalRandom.current().nextInt(menosLlenos.size()));
			return new ProyectoAulaCreado(
					inscribirEnProyecto(tutoria, asignado, estudianteId), null);
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
		String nombre = solicitud.nombre().trim();
		String codigo = generarCodigoInscripcion();
		ProyectoAula proyecto = new ProyectoAula(
				UUID.randomUUID().toString(),
				nombre,
				responsable,
				List.of(estudianteId),
				tutoria.tecnologia(),
				tutoria.semestre(), codigo, estudianteId);
		TutoriaColectiva actualizado = tutoria.actualizarProyecto(proyecto);
		tutoriaColectivaRepositorio.save(actualizado);
		notificationService.notifyUser(responsable, "Nuevo estudiante en tu proyecto",
				"Un estudiante se unio al proyecto " + proyecto.nombre() + ".", "/notificaciones");
		notificationService.notifyUser(estudianteId, "Proyecto creado",
				"Creaste el proyecto " + proyecto.nombre() + " y quedaste inscrito.", "/notificaciones");
		return new ProyectoAulaCreado(disponible(tutoriaId, proyecto, estudianteId), null);
	}

	public ProyectoAulaInscripcionPreview previsualizarInscripcion(String codigo, String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		ProyectoUbicado ubicado = buscarPorCodigo(codigo);
		validarTecnologia(estudiante, ubicado.proyecto().tecnologia());
		validarInscripcionUnica(ubicado.tutoria(), estudianteId, ubicado.proyecto().proyectoId());
		if (ubicado.proyecto().estudianteIds().size() >= 4
				&& !ubicado.proyecto().estudianteIds().contains(estudianteId)) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "Este proyecto ya tiene cuatro estudiantes inscritos.");
		}
		String creadorId = ubicado.proyecto().creadorId();
		if (creadorId == null && !ubicado.proyecto().estudianteIds().isEmpty()) {
			creadorId = ubicado.proyecto().estudianteIds().get(0);
		}
		String creador = creadorId == null
				? "Estudiante"
				: userRepository.findById(creadorId).map(User::getNombre).orElse("Estudiante");
		return new ProyectoAulaInscripcionPreview(ubicado.tutoria().id(), ubicado.proyecto().proyectoId(),
				ubicado.proyecto().nombre(), creador, ubicado.proyecto().tecnologia(), ubicado.proyecto().semestre(),
				ubicado.proyecto().estudianteIds().size());
	}

	public ProyectoAulaDisponible inscribirPorCodigo(ProyectoAulaCodigoSolicitud solicitud, String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		ProyectoUbicado ubicado = buscarPorCodigo(solicitud.codigo());
		validarTecnologia(estudiante, ubicado.proyecto().tecnologia());
		validarInscripcionUnica(ubicado.tutoria(), estudianteId, ubicado.proyecto().proyectoId());
		return inscribirEnProyecto(ubicado.tutoria(), ubicado.proyecto(), estudianteId);
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

	private boolean esDocenteActivoDeTecnologia(User user) {
		return user.getRol() != null && user.getRol().toLowerCase(java.util.Locale.ROOT).contains("docente")
				&& (user.getEstado() == null || user.getEstado().isBlank()
						|| "Activo".equalsIgnoreCase(user.getEstado()));
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
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "El código debe tener seis dígitos.");
		}
		return tutoriaColectivaRepositorio.findAll().stream()
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.filter(proyecto -> codigo.equals(proyecto.codigoInscripcion()))
						.map(proyecto -> new ProyectoUbicado(tutoria, proyecto)))
				.findFirst()
				.orElseThrow(() -> new NotFoundException("No se encontró un proyecto con ese código."));
	}

	private record ProyectoUbicado(TutoriaColectiva tutoria, ProyectoAula proyecto) {}

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
