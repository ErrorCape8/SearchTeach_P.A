package com.pa.searchteach.it.controller;

import com.pa.searchteach.it.dto.AsignacionMateriasDocenteRequest;
import com.pa.searchteach.it.dto.DocenteMateriasResponse;
import com.pa.searchteach.it.service.ItDocenteService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/docentes")
public class ItDocenteController {

	private final ItDocenteService service;

	public ItDocenteController(ItDocenteService service) {
		this.service = service;
	}

	@GetMapping
	public List<DocenteMateriasResponse> listarDocentesParaAdministracion() {
		return service.listarDocentes();
	}

	@GetMapping("/{id}/materias")
	public DocenteMateriasResponse obtenerMateriasDelDocente(@PathVariable String id) {
		return service.obtener(id);
	}

	@PutMapping("/{id}/materias")
	public DocenteMateriasResponse asignarMateriasAlDocente(
			@PathVariable String id,
			@Valid @RequestBody AsignacionMateriasDocenteRequest request) {
		return service.asignar(id, request);
	}
}