package com.pa.searchteach.tutorias.controller;

import java.util.List;

import com.pa.searchteach.tutorias.dto.DocenteCoordinacion;
import com.pa.searchteach.tutorias.dto.HorarioTutorSolicitud;
import com.pa.searchteach.tutorias.model.MateriaHorario;
import com.pa.searchteach.tutorias.model.HorarioTutor;
import com.pa.searchteach.tutorias.service.HorariosTutoresService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ControladorHorariosTutores {

	private final HorariosTutoresService servicio;

	public ControladorHorariosTutores(HorariosTutoresService servicio) {
		this.servicio = servicio;
	}

	@GetMapping("/api/coordinacion/docentes")
	public List<DocenteCoordinacion> listarDocentesParaCoordinacion() {
		return servicio.listarDocentes();
	}

	@GetMapping("/api/coordinacion/horarios")
	public List<HorarioTutor> listarHorariosDeTutores() {
		return servicio.listarHorarios();
	}

	@GetMapping("/api/coordinacion/horarios/materias")
	public List<MateriaHorario> listarMateriasParaHorario(
			@RequestParam String carrera,
			@RequestParam int semestre) {
		return servicio.listarMaterias(carrera, semestre);
	}

	@PostMapping("/api/coordinacion/horarios/{docenteId}")
	@ResponseStatus(HttpStatus.CREATED)
	public HorarioTutor crearHorarioTutor(
			@PathVariable String docenteId,
			@Valid @RequestBody HorarioTutorSolicitud solicitud) {
		return servicio.crear(docenteId, solicitud);
	}

	@PutMapping("/api/coordinacion/horarios/{docenteId}")
	public HorarioTutor actualizarHorarioTutor(
			@PathVariable String docenteId,
			@Valid @RequestBody HorarioTutorSolicitud solicitud) {
		return servicio.actualizar(docenteId, solicitud);
	}

	@DeleteMapping("/api/coordinacion/horarios/{docenteId}")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void eliminarHorarioTutor(@PathVariable String docenteId) {
		servicio.eliminar(docenteId);
	}
}
