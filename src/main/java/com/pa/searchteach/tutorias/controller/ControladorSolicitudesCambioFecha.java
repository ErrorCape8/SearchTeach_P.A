package com.pa.searchteach.tutorias.controller;

import java.util.List;
import com.pa.searchteach.tutorias.dto.ResolverSolicitudCambioFecha;
import com.pa.searchteach.tutorias.model.SolicitudCambioFechaSesion;
import com.pa.searchteach.tutorias.service.SesionesGrupalesTutoriaService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/coordinacion/solicitudes-cambio-fecha")
public class ControladorSolicitudesCambioFecha {
	private final SesionesGrupalesTutoriaService sesiones;

	public ControladorSolicitudesCambioFecha(SesionesGrupalesTutoriaService sesiones) {
		this.sesiones = sesiones;
	}

	@GetMapping
	public List<SolicitudCambioFechaSesion> listarPendientes() {
		return sesiones.listarSolicitudesCambioPendientes();
	}

	@PatchMapping("/{id}")
	public SolicitudCambioFechaSesion resolver(@PathVariable String id,
			@Valid @RequestBody ResolverSolicitudCambioFecha resolucion) {
		return sesiones.resolverSolicitudCambio(id, resolucion);
	}
}
