package com.pa.searchteach.tutorias.controller;

import java.util.List;

import com.pa.searchteach.tutorias.dto.ProgramarTutoriasSolicitud;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.service.SesionesGrupalesTutoriaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/coordinacion/sesiones-grupales")
public class ControladorProgramacionTutorias {

	private final SesionesGrupalesTutoriaService sesiones;

	public ControladorProgramacionTutorias(SesionesGrupalesTutoriaService sesiones) {
		this.sesiones = sesiones;
	}

	@GetMapping
	public List<SesionTutoria> listarPublicadas() {
		return sesiones.listarPublicadas();
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public List<SesionTutoria> programar(@Valid @RequestBody ProgramarTutoriasSolicitud solicitud) {
		return sesiones.programar(solicitud);
	}

	@PutMapping("/{sesionId}")
	public SesionTutoria editar(@PathVariable String sesionId,
			@Valid @RequestBody ProgramarTutoriasSolicitud solicitud) {
		return sesiones.editarPublicada(sesionId, solicitud);
	}

	@DeleteMapping("/{sesionId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void eliminar(@PathVariable String sesionId) {
		sesiones.eliminarPublicada(sesionId);
	}
}
