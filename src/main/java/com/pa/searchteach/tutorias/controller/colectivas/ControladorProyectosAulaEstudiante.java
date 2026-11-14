package com.pa.searchteach.tutorias.controller.colectivas;

import java.util.List;

import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaSeguimientoEstudiante;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaDisponible;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaNombreSolicitud;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaCreado;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaCodigoSolicitud;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaInscripcionPreview;
import com.pa.searchteach.tutorias.dto.colectivas.TutoriaColectivaEstudiante;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import com.pa.searchteach.tutorias.service.colectivas.ConsultaProyectosAulaService;
import com.pa.searchteach.tutorias.service.colectivas.InscripcionProyectosAulaService;
import com.pa.searchteach.tutorias.service.colectivas.ReunionesProyectoAulaService;

/** Proyectos de aula: acciones del estudiante. */
@RestController
public class ControladorProyectosAulaEstudiante {

	private final ConsultaProyectosAulaService consulta;
	private final InscripcionProyectosAulaService inscripcion;
	private final ReunionesProyectoAulaService reuniones;

	public ControladorProyectosAulaEstudiante(
			ConsultaProyectosAulaService consulta,
			InscripcionProyectosAulaService inscripcion,
			ReunionesProyectoAulaService reuniones) {
		this.consulta = consulta;
		this.inscripcion = inscripcion;
		this.reuniones = reuniones;
	}

	@GetMapping("/api/estudiante/tutorias-colectivas/espacios")
	public List<TutoriaColectivaEstudiante> listarEspaciosColectivosParaEstudiante(
			@AuthenticationPrincipal String estudianteId) {
		return inscripcion.listarEspaciosParaEstudiante(estudianteId);
	}

	@GetMapping("/api/estudiante/tutorias-colectivas/seguimiento")
	public List<ProyectoAulaSeguimientoEstudiante> listarSeguimientoDeProyectosParaEstudiante(
			@AuthenticationPrincipal String estudianteId) {
		return consulta.listarSeguimientoEstudiante(estudianteId);
	}

	@GetMapping("/api/estudiante/tutorias-colectivas/proyectos/codigo/{codigo}")
	public ProyectoAulaInscripcionPreview previsualizarProyectoPorCodigo(
			@PathVariable String codigo,
			@AuthenticationPrincipal String estudianteId) {
		return inscripcion.previsualizarInscripcion(codigo, estudianteId);
	}

	@PostMapping("/api/estudiante/tutorias-colectivas/proyectos/inscripcion-codigo")
	public ProyectoAulaDisponible inscribirEstudiantePorCodigo(
			@Valid @RequestBody ProyectoAulaCodigoSolicitud solicitud,
			@AuthenticationPrincipal String estudianteId) {
		return inscripcion.inscribirPorCodigo(solicitud, estudianteId);
	}

	@PostMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos")
	public ResponseEntity<ProyectoAulaCreado> crearProyectoDeTutoria(
			@PathVariable String tutoriaId,
			@Valid @RequestBody ProyectoAulaNombreSolicitud solicitud,
			@AuthenticationPrincipal String estudianteId) {
		ProyectoAulaCreado resultado = inscripcion.crearProyecto(tutoriaId, solicitud, estudianteId);
		return ResponseEntity.status(HttpStatus.CREATED).body(resultado);
	}

	@DeleteMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/inscripcion")
	public ProyectoAulaDisponible desistirEstudianteDeProyecto(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@AuthenticationPrincipal String estudianteId) {
		return inscripcion.desistirEstudiante(tutoriaId, proyectoId, estudianteId);
	}

	@PostMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/reunion/respuesta")
	public com.pa.searchteach.tutorias.model.RespuestaReunionProyectoAula responderReunion(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@RequestParam boolean acepta, @AuthenticationPrincipal String estudianteId) {
		return reuniones.responderReunion(tutoriaId, proyectoId, sesionId, estudianteId, acepta);
	}
}
