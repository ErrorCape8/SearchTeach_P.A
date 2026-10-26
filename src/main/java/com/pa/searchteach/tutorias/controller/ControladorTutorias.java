package com.pa.searchteach.tutorias.controller;

import java.util.List;

import com.pa.searchteach.tutorias.dto.PropuestaHorario;
import com.pa.searchteach.tutorias.dto.InscripcionTutoriaGrupal;
import com.pa.searchteach.tutorias.dto.RegistroAsistencia;
import com.pa.searchteach.tutorias.dto.SolicitudCambioFechaTutoria;
import com.pa.searchteach.tutorias.dto.SolicitudTutoria;
import com.pa.searchteach.tutorias.dto.TutorDisponible;
import com.pa.searchteach.tutorias.model.Tutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.service.SesionesGrupalesTutoriaService;
import com.pa.searchteach.tutorias.service.ServicioTutorias;
import com.pa.searchteach.tutorias.service.HorariosTutoresService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/tutorias")
public class ControladorTutorias {

	private final ServicioTutorias servicioTutorias;
	private final HorariosTutoresService horariosTutoresService;
	private final SesionesGrupalesTutoriaService sesionesGrupalesService;

	public ControladorTutorias(
			ServicioTutorias servicioTutorias,
			HorariosTutoresService horariosTutoresService,
			SesionesGrupalesTutoriaService sesionesGrupalesService) {
		this.servicioTutorias = servicioTutorias;
		this.horariosTutoresService = horariosTutoresService;
		this.sesionesGrupalesService = sesionesGrupalesService;
	}

	@GetMapping("/disponibles")
	public List<TutorDisponible> listarTutoresDisponibles(@AuthenticationPrincipal String estudianteId) {
		return horariosTutoresService.listarDisponibles(estudianteId);
	}

	@GetMapping("/grupales")
	public List<SesionTutoria> listarSesionesGrupalesDeEstudiante(@AuthenticationPrincipal String usuarioId) {
		return sesionesGrupalesService.listarDeEstudiante(usuarioId);
	}

	@GetMapping("/grupales/docente")
	public List<SesionTutoria> listarSesionesGrupalesDeDocente(@AuthenticationPrincipal String docenteId) {
		return sesionesGrupalesService.listarDeDocente(docenteId);
	}

	@GetMapping("/grupales/disponibles")
	public List<SesionTutoria> listarSesionesGrupalesDisponibles(@AuthenticationPrincipal String estudianteId) {
		return sesionesGrupalesService.listarDisponibles(estudianteId);
	}

	@PostMapping("/grupales/inscripcion")
	@ResponseStatus(HttpStatus.CREATED)
	public SesionTutoria inscribirEnGrupal(
			@Valid @RequestBody InscripcionTutoriaGrupal solicitud,
			@AuthenticationPrincipal String usuarioId) {
		return sesionesGrupalesService.inscribir(solicitud, usuarioId);
	}

	@DeleteMapping("/grupales/{id}/inscripcion")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void desistirDeGrupal(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		sesionesGrupalesService.desistir(id, usuarioId);
	}

	@PostMapping("/grupales/{id}/solicitud-cambio-fecha")
	@ResponseStatus(HttpStatus.CREATED)
	public void solicitarCambioFechaGrupal(
			@PathVariable String id,
			@Valid @RequestBody SolicitudCambioFechaTutoria solicitud,
			@AuthenticationPrincipal String docenteId) {
		sesionesGrupalesService.solicitarCambioFecha(id, docenteId, solicitud);
	}

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public Tutoria solicitarTutoria(
			@Valid @RequestBody SolicitudTutoria solicitud,
			@AuthenticationPrincipal String usuarioId) {
		if (usuarioId.equals(solicitud.docenteId())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"No puedes inscribirte en una tutoría contigo mismo.");
		}
		horariosTutoresService.validarDisponibilidad(
				solicitud.docenteId(),
				solicitud.modalidad().name(),
				solicitud.fechaInicio(),
				solicitud.fechaFin());
		horariosTutoresService.validarMateria(
				solicitud.docenteId(), usuarioId, solicitud.materia());
		return servicioTutorias.solicitar(solicitud, usuarioId);
	}

	@GetMapping
	public List<Tutoria> listarTutoriasDelUsuario(@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.listarDelUsuario(usuarioId);
	}

	@GetMapping("/{id}")
	public Tutoria buscarTutoria(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.buscar(id, usuarioId);
	}

	@PatchMapping("/{id}/aceptar")
	public Tutoria aceptarTutoria(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.aceptar(id, usuarioId);
	}

	@PatchMapping("/{id}/proponer-horario")
	public Tutoria proponerHorarioTutoria(
			@PathVariable String id,
			@Valid @RequestBody PropuestaHorario propuesta,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.proponerHorario(id, propuesta, usuarioId);
	}

	@PatchMapping("/{id}/confirmar-alternativa")
	public Tutoria confirmarHorarioAlternativoTutoria(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.confirmarAlternativa(id, usuarioId);
	}

	@PatchMapping("/{id}/cancelar")
	public Tutoria cancelarTutoria(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.cancelar(id, usuarioId);
	}

	@PatchMapping("/{id}/iniciar")
	public Tutoria iniciarTutoria(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.iniciar(id, usuarioId);
	}

	@PatchMapping("/{id}/finalizar")
	public Tutoria finalizarTutoria(
			@PathVariable String id,
			@Valid @RequestBody RegistroAsistencia asistencia,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.finalizar(id, asistencia, usuarioId);
	}
}
