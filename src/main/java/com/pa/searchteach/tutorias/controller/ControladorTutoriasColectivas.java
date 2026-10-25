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
import com.pa.searchteach.tutorias.dto.TutoriaColectivaEstudiante;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.model.SesionProyectoAula;
import com.pa.searchteach.tutorias.model.MensajeProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.service.TutoriasColectivasService;
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

@RestController
public class ControladorTutoriasColectivas {

	private final TutoriasColectivasService servicio;

	public ControladorTutoriasColectivas(TutoriasColectivasService servicio) {
		this.servicio = servicio;
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

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/solicitud-cierre")
	public com.pa.searchteach.tutorias.model.ProyectoAula solicitarCierreDeProyecto(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@Valid @RequestBody CierreProyectoAulaSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return servicio.solicitarCierreProyecto(tutoriaId, proyectoId, solicitud.motivo(), docenteId);
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
		return servicio.registrarMensajeProyecto(tutoriaId, proyectoId, sesionId, usuarioId, texto, archivo);
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
	public void eliminarTutoriaColectiva(@PathVariable String tutoriaId) {
		servicio.eliminar(tutoriaId);
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
