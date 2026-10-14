package com.pa.searchteach.tutorias.controlador;

import java.util.List;

import com.pa.searchteach.tutorias.dto.InformeAvanceSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.dto.ProyectoAulaDisponible;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaConAvance;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.modelo.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.modelo.TutoriaColectiva;
import com.pa.searchteach.tutorias.servicio.TutoriasColectivasService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ControladorTutoriasColectivas {

	private final TutoriasColectivasService servicio;

	public ControladorTutoriasColectivas(TutoriasColectivasService servicio) {
		this.servicio = servicio;
	}

	@PostMapping("/api/coordinacion/tutorias-colectivas")
	@ResponseStatus(HttpStatus.CREATED)
	public TutoriaColectiva crear(
			@Valid @RequestBody TutoriaColectivaSolicitud solicitud,
			@AuthenticationPrincipal String coordinadoraId) {
		return servicio.crear(solicitud, coordinadoraId);
	}

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/informes")
	@ResponseStatus(HttpStatus.CREATED)
	public InformeAvanceProyecto registrarInforme(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@Valid @RequestBody InformeAvanceSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return servicio.registrarInforme(tutoriaId, proyectoId, solicitud, docenteId);
	}

	@GetMapping("/api/docente/tutorias-colectivas")
	public List<ProyectoAsignadoDocente> listarProyectosDeDocente(
			@AuthenticationPrincipal String docenteId) {
		return servicio.listarProyectosDeDocente(docenteId);
	}

	@GetMapping("/api/direccion/tutorias-colectivas")
	public List<TutoriaColectivaConAvance> listarParaLiderPrograma() {
		return servicio.listarParaLiderPrograma();
	}

	@GetMapping("/api/coordinacion/tutorias-colectivas")
	public List<TutoriaColectiva> listarParaCoordinacion() {
		return servicio.listarParaCoordinacion();
	}

	@GetMapping("/api/estudiante/tutorias-colectivas/espacios")
	public List<ProyectoAulaDisponible> listarEspaciosParaEstudiante(
			@AuthenticationPrincipal String estudianteId) {
		return servicio.listarEspaciosParaEstudiante(estudianteId);
	}

	@PostMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/inscripcion")
	@ResponseStatus(HttpStatus.OK)
	public ProyectoAulaDisponible inscribirEstudiante(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.inscribirEstudiante(tutoriaId, proyectoId, estudianteId);
	}

	@DeleteMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/inscripcion")
	public ProyectoAulaDisponible desistirEstudiante(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.desistirEstudiante(tutoriaId, proyectoId, estudianteId);
	}

	@GetMapping("/api/coordinacion/informes")
	public List<InformeAvanceProyecto> listarInformesParaCoordinacion() {
		return servicio.listarInformesParaCoordinacion();
	}
}
