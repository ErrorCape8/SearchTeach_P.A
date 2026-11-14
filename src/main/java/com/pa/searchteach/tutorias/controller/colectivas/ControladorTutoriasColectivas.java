package com.pa.searchteach.tutorias.controller.colectivas;

import java.util.List;

import com.pa.searchteach.tutorias.dto.colectivas.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.service.grupal.ReporteMensualService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ContentDisposition;
import com.pa.searchteach.tutorias.service.colectivas.GestionTutoriasColectivasService;
import com.pa.searchteach.tutorias.service.colectivas.InformeGeneralTutoriaService;
import com.pa.searchteach.tutorias.service.grupal.RelojTutorias;

/** Coordinación: crear, listar, editar, eliminar y disolver tutorías colectivas. */
@RestController
public class ControladorTutoriasColectivas {

	private final GestionTutoriasColectivasService gestion;
	private final ReporteMensualService reporteMensual;
	private final InformeGeneralTutoriaService informeGeneral;

	public ControladorTutoriasColectivas(
			GestionTutoriasColectivasService gestion,
			ReporteMensualService reporteMensual,
			InformeGeneralTutoriaService informeGeneral) {
		this.gestion = gestion;
		this.reporteMensual = reporteMensual;
		this.informeGeneral = informeGeneral;
	}

	@PostMapping("/api/coordinacion/tutorias-colectivas")
	@ResponseStatus(HttpStatus.CREATED)
	public TutoriaColectiva crearTutoriaColectiva(
			@Valid @RequestBody TutoriaColectivaSolicitud solicitud,
			@AuthenticationPrincipal String coordinadoraId) {
		return gestion.crear(solicitud, coordinadoraId);
	}

	@GetMapping(value = "/api/coordinacion/reportes-tutorias/mensual", produces = "text/csv")
	public ResponseEntity<String> descargarReporteMensual(
			@RequestParam(required = false) Integer anio,
			@RequestParam(required = false) Integer mes,
			@AuthenticationPrincipal String coordinadorId) {
		if (!reporteMensual.esCoordinador(coordinadorId)) {
			return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
		}
		java.time.LocalDate hoy = RelojTutorias.ahora().toLocalDate();
		int year = anio == null ? hoy.getYear() : anio;
		int month = mes == null ? hoy.getMonthValue() : mes;
		if (month < 1 || month > 12 || year < 2000 || year > hoy.getYear() + 1) {
			return ResponseEntity.badRequest().build();
		}
		java.time.LocalDateTime inicio = java.time.LocalDateTime.of(year, month, 1, 0, 0);
		java.time.LocalDateTime fin = inicio.plusMonths(1);
		String csv = reporteMensual.generarReporteMensual(inicio, fin);
		return ResponseEntity.ok()
				.header(HttpHeaders.CONTENT_DISPOSITION,
						ContentDisposition.attachment().filename("reporte-tutorias-" + year + "-"
								+ String.format("%02d", month) + ".csv").build().toString())
				.header(HttpHeaders.CONTENT_TYPE, "text/csv; charset=UTF-8")
				.body(csv);
	}

	@GetMapping("/api/direccion/tutorias-colectivas")
	public List<TutoriaColectiva> listarTutoriasColectivasParaDireccion() {
		return gestion.listarParaLiderPrograma();
	}

	@GetMapping("/api/coordinacion/tutorias-colectivas")
	public List<TutoriaColectiva> listarTutoriasColectivasParaCoordinacion() {
		return gestion.listarParaCoordinacion();
	}

	@PutMapping("/api/coordinacion/tutorias-colectivas/{tutoriaId}")
	public TutoriaColectiva actualizarTutoriaColectiva(
			@PathVariable String tutoriaId,
			@Valid @RequestBody TutoriaColectivaSolicitud solicitud) {
		return gestion.actualizar(tutoriaId, solicitud);
	}

	@DeleteMapping("/api/coordinacion/tutorias-colectivas/{tutoriaId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void eliminarTutoriaColectiva(
			@PathVariable String tutoriaId, @RequestParam String confirmacion) {
		gestion.eliminar(tutoriaId, confirmacion);
	}

	@PostMapping("/api/coordinacion/tutorias-colectivas/{tutoriaId}/disolver")
	public TutoriaColectiva disolverTutoriaColectiva(
			@PathVariable String tutoriaId, @RequestParam String confirmacion) {
		return gestion.disolver(tutoriaId, confirmacion);
	}

	@GetMapping("/api/coordinacion/tutorias-colectivas/{tutoriaId}/informe-general")
	public InformeAvanceProyecto consultarInformeGeneral(@PathVariable String tutoriaId) {
		return informeGeneral.consultarComoCoordinacion(tutoriaId);
	}

	@GetMapping("/api/coordinacion/informes-generales")
	public List<InformeAvanceProyecto> listarInformesGenerales() {
		return informeGeneral.listarParaCoordinacion();
	}
}
