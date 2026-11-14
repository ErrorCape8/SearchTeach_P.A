package com.pa.searchteach.tutorias.controller.colectivas;

import java.util.List;

import com.pa.searchteach.tutorias.dto.colectivas.SesionProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.colectivas.ReunionProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.colectivas.CierreProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.colectivas.InformeGeneralSolicitud;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.model.SesionProyectoAula;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import com.pa.searchteach.tutorias.service.colectivas.ConsultaProyectosAulaService;
import com.pa.searchteach.tutorias.service.colectivas.SesionesProyectoAulaService;
import com.pa.searchteach.tutorias.service.colectivas.ReunionesProyectoAulaService;
import com.pa.searchteach.tutorias.service.colectivas.CierreProyectosAulaService;
import com.pa.searchteach.tutorias.service.colectivas.InformeGeneralTutoriaService;

/** Proyectos de aula: acciones del docente de apoyo y del docente líder. */
@RestController
public class ControladorProyectosAulaDocente {

	private final ConsultaProyectosAulaService consulta;
	private final SesionesProyectoAulaService sesiones;
	private final ReunionesProyectoAulaService reuniones;
	private final CierreProyectosAulaService cierre;
	private final InformeGeneralTutoriaService informeGeneral;

	public ControladorProyectosAulaDocente(
			ConsultaProyectosAulaService consulta,
			SesionesProyectoAulaService sesiones,
			ReunionesProyectoAulaService reuniones,
			CierreProyectosAulaService cierre,
			InformeGeneralTutoriaService informeGeneral) {
		this.consulta = consulta;
		this.sesiones = sesiones;
		this.reuniones = reuniones;
		this.cierre = cierre;
		this.informeGeneral = informeGeneral;
	}

	@GetMapping("/api/docente/tutorias-colectivas")
	public List<ProyectoAsignadoDocente> listarProyectosAsignadosAlDocente(
			@AuthenticationPrincipal String docenteId) {
		return consulta.listarProyectosDeDocente(docenteId);
	}

	@GetMapping("/api/docente/tutorias-colectivas/lider")
	public List<ProyectoAsignadoDocente> listarProyectosParaRevisionDelLider(
			@AuthenticationPrincipal String docenteLiderId) {
		return consulta.listarProyectosParaLider(docenteLiderId);
	}

	@GetMapping("/api/docente/tutorias-colectivas/lider/asignaciones")
	public List<com.pa.searchteach.tutorias.dto.colectivas.TutoriaColectivaLider> listarTutoriasAsignadasAlLider(
			@AuthenticationPrincipal String docenteLiderId) {
		return consulta.listarTutoriasParaLider(docenteLiderId);
	}

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/reunion")
	public com.pa.searchteach.tutorias.model.ProyectoAula programarReunionDeProyecto(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@Valid @RequestBody ReunionProyectoAulaSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return reuniones.programarReunionProyecto(tutoriaId, proyectoId, sesionId, solicitud, docenteId);
	}

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/solicitud-cierre")
	public com.pa.searchteach.tutorias.model.ProyectoAula solicitarCierreDeProyecto(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@Valid @RequestBody CierreProyectoAulaSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return cierre.solicitarCierreProyecto(
				tutoriaId, proyectoId, solicitud.motivo(), solicitud.reporte(), docenteId);
	}

	@PostMapping("/api/docente/lider/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/confirmacion-cierre")
	public com.pa.searchteach.tutorias.model.ProyectoAula responderSolicitudDeCierre(
			@PathVariable String tutoriaId, @PathVariable String proyectoId,
			@RequestParam boolean confirmar,
			@AuthenticationPrincipal String docenteLiderId) {
		return cierre.responderSolicitudCierre(tutoriaId, proyectoId, confirmar, docenteLiderId);
	}

	@PostMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones")
	@ResponseStatus(HttpStatus.CREATED)
	public SesionProyectoAula registrarSesionDeProyecto(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@Valid @RequestBody SesionProyectoAulaSolicitud solicitud,
			@AuthenticationPrincipal String docenteId) {
		return sesiones.registrarSesionProyecto(tutoriaId, proyectoId, solicitud, docenteId);
	}

	@GetMapping("/api/docente/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones")
	public List<SesionProyectoAula> listarSesionesDelProyecto(
			@PathVariable String tutoriaId,
			@PathVariable String proyectoId,
			@AuthenticationPrincipal String docenteId) {
		return sesiones.listarSesionesProyectoDocente(tutoriaId, proyectoId, docenteId);
	}

	@PostMapping("/api/docente/lider/tutorias-colectivas/{tutoriaId}/proyectos/{proyectoId}/sesiones/{sesionId}/confirmacion")
	public SesionProyectoAula confirmarReporteDeApoyo(
			@PathVariable String tutoriaId, @PathVariable String proyectoId, @PathVariable String sesionId,
			@AuthenticationPrincipal String docenteLiderId) {
		return sesiones.confirmarReporteProyecto(tutoriaId, proyectoId, sesionId, docenteLiderId);
	}

	@PostMapping("/api/docente/lider/tutorias-colectivas/{tutoriaId}/informe-general")
	@ResponseStatus(HttpStatus.CREATED)
	public InformeAvanceProyecto enviarInformeGeneral(
			@PathVariable String tutoriaId,
			@Valid @RequestBody InformeGeneralSolicitud solicitud,
			@AuthenticationPrincipal String docenteLiderId) {
		return informeGeneral.enviar(tutoriaId, solicitud.contenido(), docenteLiderId);
	}

	@GetMapping("/api/docente/lider/tutorias-colectivas/{tutoriaId}/informe-general")
	public InformeAvanceProyecto consultarInformeGeneral(
			@PathVariable String tutoriaId,
			@AuthenticationPrincipal String docenteLiderId) {
		return informeGeneral.consultarComoLider(tutoriaId, docenteLiderId);
	}
}
