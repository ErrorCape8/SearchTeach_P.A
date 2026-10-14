package com.pa.searchteach.tutorias.controlador;

import java.util.List;

import com.pa.searchteach.tutorias.dto.PropuestaHorario;
import com.pa.searchteach.tutorias.dto.InscripcionTutoriaGrupal;
import com.pa.searchteach.tutorias.dto.RegistroAsistencia;
import com.pa.searchteach.tutorias.dto.SolicitudTutoria;
import com.pa.searchteach.tutorias.dto.TutorDisponible;
import com.pa.searchteach.tutorias.modelo.Tutoria;
import com.pa.searchteach.tutorias.modelo.SesionTutoria;
import com.pa.searchteach.tutorias.servicio.SesionesGrupalesTutoriaService;
import com.pa.searchteach.tutorias.servicio.ServicioTutorias;
import com.pa.searchteach.tutorias.servicio.HorariosTutoresService;
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
	public List<TutorDisponible> listarDisponibles() {
		return horariosTutoresService.listarDisponibles();
	}

	@GetMapping("/grupales")
	public List<SesionTutoria> listarGrupales(@AuthenticationPrincipal String usuarioId) {
		return sesionesGrupalesService.listarDeEstudiante(usuarioId);
	}

	@GetMapping("/grupales/docente")
	public List<SesionTutoria> listarGrupalesDocente(@AuthenticationPrincipal String docenteId) {
		return sesionesGrupalesService.listarDeDocente(docenteId);
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

	@PostMapping
	@ResponseStatus(HttpStatus.CREATED)
	public Tutoria solicitar(
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
	public List<Tutoria> listar(@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.listarDelUsuario(usuarioId);
	}

	@GetMapping("/{id}")
	public Tutoria buscar(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.buscar(id, usuarioId);
	}

	@PatchMapping("/{id}/aceptar")
	public Tutoria aceptar(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.aceptar(id, usuarioId);
	}

	@PatchMapping("/{id}/proponer-horario")
	public Tutoria proponerHorario(
			@PathVariable String id,
			@Valid @RequestBody PropuestaHorario propuesta,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.proponerHorario(id, propuesta, usuarioId);
	}

	@PatchMapping("/{id}/confirmar-alternativa")
	public Tutoria confirmarAlternativa(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.confirmarAlternativa(id, usuarioId);
	}

	@PatchMapping("/{id}/cancelar")
	public Tutoria cancelar(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.cancelar(id, usuarioId);
	}

	@PatchMapping("/{id}/iniciar")
	public Tutoria iniciar(
			@PathVariable String id,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.iniciar(id, usuarioId);
	}

	@PatchMapping("/{id}/finalizar")
	public Tutoria finalizar(
			@PathVariable String id,
			@Valid @RequestBody RegistroAsistencia asistencia,
			@AuthenticationPrincipal String usuarioId) {
		return servicioTutorias.finalizar(id, asistencia, usuarioId);
	}
}
