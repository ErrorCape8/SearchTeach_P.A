package com.pa.searchteach.tutorias.controller;

import java.util.List;

import com.pa.searchteach.tutorias.dto.InformeAvanceSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.dto.ProyectoAulaDisponible;
import com.pa.searchteach.tutorias.dto.ProyectoAulaNombreSolicitud;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaEstudiante;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaConAvance;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.service.TutoriasColectivasService;
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
	public TutoriaColectiva crearTutoriaColectiva(
			@Valid @RequestBody TutoriaColectivaSolicitud solicitud,
			@AuthenticationPrincipal String coordinadoraId) {
		return servicio.crear(solicitud, coordinadoraId);
	}

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/informes")
	@ResponseStatus(HttpStatus.CREATED)
	public InformeAvanceProyecto registrarInformeDeAvance(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@Valid @RequestBody InformeAvanceSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return servicio.registrarInforme(tutoriaId, proyectoId, solicitud, docenteId);
	}

	@GetMapping("/api/docente/tutorias-colectivas")
	public List<ProyectoAsignadoDocente> listarProyectosAsignadosAlDocente(
			@AuthenticationPrincipal String docenteId) {
		return servicio.listarProyectosDeDocente(docenteId);
	}

	@GetMapping("/api/direccion/tutorias-colectivas")
	public List<TutoriaColectivaConAvance> listarTutoriasColectivasParaDireccion() {
		return servicio.listarParaLiderPrograma();
	}

	@GetMapping("/api/coordinacion/tutorias-colectivas")
	public List<TutoriaColectiva> listarTutoriasColectivasParaCoordinacion() {
		return servicio.listarParaCoordinacion();
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

	@PostMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos")
	@ResponseStatus(HttpStatus.CREATED)
	public ProyectoAulaDisponible crearOUnirseAProyectoDeTutoria(
			@PathVariable String tutoriaId,
			@Valid @RequestBody ProyectoAulaNombreSolicitud solicitud,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.crearOUnirseAProyecto(tutoriaId, solicitud, estudianteId);
	}

	@PostMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/inscripcion")
	@ResponseStatus(HttpStatus.OK)
	public ProyectoAulaDisponible inscribirEstudianteEnProyecto(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.inscribirEstudiante(tutoriaId, proyectoId, estudianteId);
	}

	@DeleteMapping("/api/estudiante/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/inscripcion")
	public ProyectoAulaDisponible desistirEstudianteDeProyecto(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@AuthenticationPrincipal String estudianteId) {
		return servicio.desistirEstudiante(tutoriaId, proyectoId, estudianteId);
	}

	@GetMapping("/api/coordinacion/informes")
	public List<InformeAvanceProyecto> listarInformesDeAvanceParaCoordinacion() {
		return servicio.listarInformesParaCoordinacion();
	}
}
