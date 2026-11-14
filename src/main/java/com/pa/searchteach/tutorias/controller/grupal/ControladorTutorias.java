package com.pa.searchteach.tutorias.controller.grupal;

import java.util.List;

import com.pa.searchteach.tutorias.dto.grupal.InscripcionTutoriaGrupal;
import com.pa.searchteach.tutorias.dto.grupal.SolicitudCambioFechaTutoria;
import com.pa.searchteach.tutorias.dto.horarios.TutorDisponible;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import com.pa.searchteach.tutorias.service.HorariosTutoresService;
import com.pa.searchteach.tutorias.service.grupal.CambioFechaSesionService;
import com.pa.searchteach.tutorias.service.grupal.InscripcionSesionesService;
import com.pa.searchteach.tutorias.service.grupal.SesionesGrupalesConsultaService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequestMapping("/api/tutorias")
public class ControladorTutorias {

	private final HorariosTutoresService horariosTutoresService;
	private final SesionesGrupalesConsultaService consultaSesiones;
	private final InscripcionSesionesService inscripcionSesiones;
	private final CambioFechaSesionService cambioFechaSesiones;
	private final ActualizacionesTutoriasService actualizacionesTutorias;

	public ControladorTutorias(
			HorariosTutoresService horariosTutoresService,
			SesionesGrupalesConsultaService consultaSesiones,
			InscripcionSesionesService inscripcionSesiones,
			CambioFechaSesionService cambioFechaSesiones,
			ActualizacionesTutoriasService actualizacionesTutorias) {
		this.horariosTutoresService = horariosTutoresService;
		this.consultaSesiones = consultaSesiones;
		this.inscripcionSesiones = inscripcionSesiones;
		this.cambioFechaSesiones = cambioFechaSesiones;
		this.actualizacionesTutorias = actualizacionesTutorias;
	}

	@GetMapping(value = "/eventos", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
	public SseEmitter eventosTutorias(@AuthenticationPrincipal String usuarioId) {
		if (usuarioId == null || usuarioId.isBlank()) {
			throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Debes iniciar sesión.");
		}
		return actualizacionesTutorias.suscribir();
	}

	@GetMapping("/disponibles")
	public List<TutorDisponible> listarTutoresDisponibles(@AuthenticationPrincipal String estudianteId) {
		return horariosTutoresService.listarDisponibles(estudianteId);
	}

	@GetMapping("/grupales")
	public List<SesionTutoria> listarSesionesGrupalesDeEstudiante(@AuthenticationPrincipal String usuarioId) {
		return consultaSesiones.listarDeEstudiante(usuarioId);
	}

	@GetMapping("/grupales/docente")
	public List<SesionTutoria> listarSesionesGrupalesDeDocente(@AuthenticationPrincipal String docenteId) {
		return consultaSesiones.listarDeDocente(docenteId);
	}

	@GetMapping("/grupales/disponibles")
	public List<SesionTutoria> listarSesionesGrupalesDisponibles(@AuthenticationPrincipal String estudianteId) {
		return consultaSesiones.listarDisponibles(estudianteId);
	}

	@PostMapping("/grupales/inscripcion")
	@ResponseStatus(HttpStatus.CREATED)
	public SesionTutoria inscribirEnGrupal(
			@Valid @RequestBody InscripcionTutoriaGrupal solicitud,
			@AuthenticationPrincipal String usuarioId) {
		return inscripcionSesiones.inscribir(solicitud, usuarioId);
	}

	@DeleteMapping("/grupales/{id}/inscripcion")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void desistirDeGrupal(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		inscripcionSesiones.desistir(id, usuarioId);
	}

	@PostMapping("/grupales/{id}/solicitud-cambio-fecha")
	@ResponseStatus(HttpStatus.CREATED)
	public void solicitarCambioFechaGrupal(
			@PathVariable String id,
			@Valid @RequestBody SolicitudCambioFechaTutoria solicitud,
			@AuthenticationPrincipal String docenteId) {
		cambioFechaSesiones.solicitarCambioFecha(id, docenteId, solicitud);
	}
}
