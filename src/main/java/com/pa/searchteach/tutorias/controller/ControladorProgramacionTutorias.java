package com.pa.searchteach.tutorias.controller;

import java.util.List;

import com.pa.searchteach.tutorias.dto.ProgramarTutoriasSolicitud;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.service.SesionesGrupalesTutoriaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/coordinacion/sesiones-grupales")
public class ControladorProgramacionTutorias {

	private final SesionesGrupalesTutoriaService sesiones;

	public ControladorProgramacionTutorias(SesionesGrupalesTutoriaService sesiones) {
		this.sesiones = sesiones;
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public List<SesionTutoria> programar(@Valid @RequestBody ProgramarTutoriasSolicitud solicitud) {
		return sesiones.programar(solicitud);
	}
}
