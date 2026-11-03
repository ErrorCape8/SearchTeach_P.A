package com.pa.searchteach.tutorias.controller;

import java.util.List;
import java.nio.charset.StandardCharsets;

import com.pa.searchteach.tutorias.dto.SesionProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.ReunionProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.CierreProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaSeguimientoEstudiante;
import com.pa.searchteach.tutorias.dto.MensajeProyectoAulaVista;
import com.pa.searchteach.tutorias.dto.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.dto.ProyectoAulaDisponible;
import com.pa.searchteach.tutorias.dto.ProyectoAulaNombreSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaCreado;
import com.pa.searchteach.tutorias.dto.ProyectoAulaCodigoSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaInscripcionPreview;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaEstudiante;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.model.SesionProyectoAula;
import com.pa.searchteach.tutorias.model.MensajeProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.service.TutoriasColectivasService;
import com.pa.searchteach.tutorias.service.SesionesGrupalesTutoriaService;
import com.pa.searchteach.tutorias.service.ProyectoAulaChatRedisService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ContentDisposition;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
public class ControladorTutoriasColectivas {

	private final TutoriasColectivasService servicio;
	private final ProyectoAulaChatRedisService chatRedis;
	private final SesionesGrupalesTutoriaService sesionesGrupales;

	public ControladorTutoriasColectivas(TutoriasColectivasService servicio,
			ProyectoAulaChatRedisService chatRedis,
			SesionesGrupalesTutoriaService sesionesGrupales) {
		this.servicio = servicio;
		this.chatRedis = chatRedis;
		this.sesionesGrupales = sesionesGrupales;
	}

	@PostMapping("/api/coordinacion/tutorias-colectivas")
	@ResponseStatus(HttpStatus.CREATED)
	public TutoriaColectiva crearTutoriaColectiva(
			@Valid @RequestBody TutoriaColectivaSolicitud solicitud,
			@AuthenticationPrincipal String coordinadoraId) {
		return servicio.crear(solicitud, coordinadoraId);
	}

	@GetMapping("/api/docente/tutorias-colectivas")
	public List<ProyectoAsignadoDocente> listarProyectosAsignadosAlDocente(
			@AuthenticationPrincipal String docenteId) {
		return servicio.listarProyectosDeDocente(docenteId);
	}

	@GetMapping(value = "/api/coordinacion/reportes-tutorias/mensual", produces = "text/csv")
	public ResponseEntity<String> descargarReporteMensual(
			@RequestParam(required = false) Integer anio,
			@RequestParam(required = false) Integer mes,
			@AuthenticationPrincipal String coordinadorId) {
		if (!sesionesGrupales.esCoordinador(coordinadorId)) {
			return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
		}
		java.time.LocalDate hoy = java.time.LocalDate.now(java.time.ZoneId.of("America/Bogota"));
		int year = anio == null ? hoy.getYear() : anio;
		int month = mes == null ? hoy.getMonthValue() : mes;
		if (month < 1 || month > 12 || year < 2000 || year > hoy.getYear() + 1) {
			return ResponseEntity.badRequest().build();
		}
		java.time.LocalDateTime inicio = java.time.LocalDateTime.of(year, month, 1, 0, 0);
		java.time.LocalDateTime fin = inicio.plusMonths(1);
		String csv = sesionesGrupales.generarReporteMensual(inicio, fin);
		return ResponseEntity.ok()
				.header(HttpHeaders.CONTENT_DISPOSITION,
						ContentDisposition.attachment().filename("reporte-tutorias-" + year + "-"
								+ String.format("%02d", month) + ".csv").build().toString())
				.header(HttpHeaders.CONTENT_TYPE, "text/csv; charset=UTF-8")
				.body(csv);
	}

	@GetMapping("/api/docente/tutorias-colectivas/lider")
	public List<ProyectoAsignadoDocente> listarProyectosParaRevisionDelLider(
			@AuthenticationPrincipal String docenteLiderId) {
		return servicio.listarProyectosParaLider(docenteLiderId);
	}

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/reunion")
	public com.pa.searchteach.tutorias.model.ProyectoAula programarReunionDeProyecto(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@Valid @RequestBody ReunionProyectoAulaSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return servicio.programarReunionProyecto(tutoriaId, proyectoId, sesionId, solicitud, docenteId);
	}

	@GetMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/reunion")
	public com.pa.searchteach.tutorias.model.RespuestaReunionProyectoAula consultarReunion(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@AuthenticationPrincipal String usuarioId) {
		return servicio.consultarReunion(tutoriaId, proyectoId, sesionId, usuarioId);
	}

	@PostMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/reunion/respuesta")
	public com.pa.searchteach.tutorias.model.RespuestaReunionProyectoAula responderReunion(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@RequestParam boolean acepta, @AuthenticationPrincipal String estudianteId) {
		return servicio.responderReunion(tutoriaId, proyectoId, sesionId, estudianteId, acepta);
	}

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/solicitud-cierre")
	public com.pa.searchteach.tutorias.model.ProyectoAula solicitarCierreDeProyecto(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@Valid @RequestBody CierreProyectoAulaSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return servicio.solicitarCierreProyecto(
				tutoriaId, proyectoId, solicitud.motivo(), solicitud.reporte(), docenteId);
	}

	@PostMapping("/api/docente/lider/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/confirmacion-cierre")
	public com.pa.searchteach.tutorias.model.ProyectoAula responderSolicitudDeCierre(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@RequestParam boolean confirmar,
			@AuthenticationPrincipal String docenteLiderId) {
		return servicio.responderSolicitudCierre(tutoriaId, proyectoId, confirmar, docenteLiderId);
	}

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones")
	@ResponseStatus(HttpStatus.CREATED)
	public SesionProyectoAula registrarSesionDeProyecto(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@Valid @RequestBody SesionProyectoAulaSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return servicio.registrarSesionProyecto(tutoriaId, proyectoId, solicitud, docenteId);
	}

	@GetMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones")
	public List<SesionProyectoAula> listarSesionesDelProyecto(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@AuthenticationPrincipal String docenteId) {
		return servicio.listarSesionesProyectoDocente(tutoriaId, proyectoId, docenteId);
	}

	@PostMapping("/api/docente/lider/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/confirmacion")
	public SesionProyectoAula confirmarReporteDeApoyo(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@AuthenticationPrincipal String docenteLiderId) {
		return servicio.confirmarReporteProyecto(tutoriaId, proyectoId, sesionId, docenteLiderId);
	}

	@GetMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/mensajes")
	public List<MensajeProyectoAulaVista> listarMensajesDelReporte(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @AuthenticationPrincipal String usuarioId) {
		return servicio.listarMensajesProyecto(tutoriaId, proyectoId, sesionId, usuarioId);
	}

	@GetMapping(value = "/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/mensajes/stream",
			produces = MediaType.TEXT_EVENT_STREAM_VALUE)
	public SseEmitter escucharMensajesDelReporte(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @AuthenticationPrincipal String usuarioId) {
		servicio.obtenerProyectoEnChat(tutoriaId, proyectoId, sesionId, usuarioId);
		return chatRedis.subscribe(tutoriaId, proyectoId, sesionId, usuarioId);
	}

	@GetMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/estado")
	public com.pa.searchteach.tutorias.model.ProyectoAula consultarEstadoDelProyectoEnChat(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @AuthenticationPrincipal String usuarioId) {
		return servicio.obtenerProyectoEnChat(tutoriaId, proyectoId, sesionId, usuarioId);
	}

	@PostMapping(value = "/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/mensajes",
			consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
	@ResponseStatus(HttpStatus.CREATED)
	public MensajeProyectoAulaVista enviarMensajeAlReporte(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @AuthenticationPrincipal String usuarioId,
			@RequestParam(value = "texto", required = false) String texto,
			@RequestPart(value = "archivo", required = false) MultipartFile archivo) {
		MensajeProyectoAulaVista mensaje = servicio.registrarMensajeProyecto(
				tutoriaId, proyectoId, sesionId, usuarioId, texto, archivo);
		chatRedis.publish(tutoriaId, proyectoId, sesionId, mensaje);
		return mensaje;
	}

	@GetMapping("/api/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/mensajes/{mensajeId}/archivo")
	public ResponseEntity<byte[]> descargarAdjuntoDelReporte(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@PathVariable String sesionId, @PathVariable String mensajeId,
			@AuthenticationPrincipal String usuarioId) {
		MensajeProyectoAula mensaje = servicio.descargarArchivoProyecto(
				tutoriaId, proyectoId, sesionId, mensajeId, usuarioId);
		return ResponseEntity.ok()
				.contentType(MediaType.parseMediaType(mensaje.archivoMime()))
				.header("X-Content-Type-Options", "nosniff")
				.header(HttpHeaders.CONTENT_DISPOSITION, org.springframework.http.ContentDisposition.attachment()
						.filename(mensaje.archivoNombre(), StandardCharsets.UTF_8).build().toString())
				.contentLength(mensaje.archivoTamano())
				.body(mensaje.archivoContenido());
	}

	@GetMapping("/api/direccion/tutorias-colectivas")
	public List<TutoriaColectiva> listarTutoriasColectivasParaDireccion() {
		return servicio.listarParaLiderPrograma();
	}

	@GetMapping("/api/coordinacion/tutorias-colectivas")
	public List<TutoriaColectiva> listarTutoriasColectivasParaCoordinacion() {
		return servicio.listarParaCoordinacion();
	}

	@PutMapping("/api/coordinacion/tutorias-colectivas/{tutoriaId}")
	public TutoriaColectiva actualizarTutoriaColectiva(
			@PathVariable String tutoriaId,
			@Valid @RequestBody TutoriaColectivaSolicitud solicitud) {
		return servicio.actualizar(tutoriaId, solicitud);
	}

	@DeleteMapping("/api/coordinacion/tutorias-colectivas/{tutoriaId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void eliminarTutoriaColectiva(
			@PathVariable String tutoriaId, @RequestParam String confirmacion) {
		servicio.eliminar(tutoriaId, confirmacion);
	}

	@PostMapping("/api/coordinacion/tutorias-colectivas/{tutoriaId}/disolver")
	public TutoriaColectiva disolverTutoriaColectiva(
			@PathVariable String tutoriaId, @RequestParam String confirmacion) {
		return servicio.disolver(tutoriaId, confirmacion);
	}

	@GetMapping("/api/estudiante/tutorias-colectivas/espacios")
	public List<TutoriaColectivaEstudiante> listarEspaciosColectivosParaEstudiante(
			@AuthenticationPrincipal String estudianteId) {
		return servicio.listarEspaciosParaEstudiante(estudianteId);
	}

	@GetMapping("/api/estudiante/tutorias-colectivas/seguimiento")
	public List<ProyectoAulaSeguimientoEstudiante> listarSeguimientoDeProyectosParaEstudiante(
			@AuthenticationPrincipal String estudianteId) {
		return servicio.listarSeguimientoEstudiante(estudianteId);
	}

	@GetMapping("/api/estudiante/tutorias-colectivas/proyectos/codigo/{codigo}")
	public ProyectoAulaInscripcionPreview previsualizarProyectoPorCodigo(
			@PathVariable String codigo,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.previsualizarInscripcion(codigo, estudianteId);
	}

	@PostMapping("/api/estudiante/tutorias-colectivas/proyectos/inscripcion-codigo")
	public ProyectoAulaDisponible inscribirEstudiantePorCodigo(
			@Valid @RequestBody ProyectoAulaCodigoSolicitud solicitud,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.inscribirPorCodigo(solicitud, estudianteId);
	}

	@PostMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos")
	@ResponseStatus(HttpStatus.CREATED)
	public ProyectoAulaCreado crearOUnirseAProyectoDeTutoria(
			@PathVariable String tutoriaId,
			@Valid @RequestBody ProyectoAulaNombreSolicitud solicitud,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.crearOUnirseAProyecto(tutoriaId, solicitud, estudianteId);
	}

	@DeleteMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/inscripcion")
	public ProyectoAulaDisponible desistirEstudianteDeProyecto(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.desistirEstudiante(tutoriaId, proyectoId, estudianteId);
	}
}
