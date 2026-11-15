package com.pa.searchteach.calidad.controller;

import com.pa.searchteach.calidad.dto.CalidadGeneralSummary;
import com.pa.searchteach.calidad.dto.RegistrarCalificacionRequest;
import com.pa.searchteach.calidad.model.CalificacionTutoria;
import com.pa.searchteach.calidad.service.DirectorCalidadService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class CalidadController {

	private final DirectorCalidadService calidadService;

	public CalidadController(DirectorCalidadService calidadService) {
		this.calidadService = calidadService;
	}

	@GetMapping("/direccion/calidad")
	public ResponseEntity<CalidadGeneralSummary> obtenerCalidadGeneral() {
		return ResponseEntity.ok(calidadService.obtenerResumenCalidad());
	}

	@PostMapping("/tutorias/calificar")
	public ResponseEntity<CalificacionTutoria> registrarCalificacion(
			@RequestBody RegistrarCalificacionRequest request) {
		return ResponseEntity.ok(calidadService.registrarCalificacion(request));
	}
}
