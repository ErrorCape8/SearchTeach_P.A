package com.pa.searchteach.tutorias.service.grupal;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.tutorias.dto.horarios.VentanaHorario;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

@Service
public class InscripcionesTutoriasEstudianteService {

	private static final int MAX_INSCRIPCIONES_ACTIVAS = 3;

	private final SesionTutoriaRepositorio sesiones;

	public InscripcionesTutoriasEstudianteService(SesionTutoriaRepositorio sesiones) {
		this.sesiones = sesiones;
	}

	/** Valida cupo máximo de inscripciones activas y cruce de horario. */
	public void validarNuevaInscripcion(String estudianteId, VentanaHorario ventana, String sesionAExcluir) {
		List<SesionTutoria> activas = sesionesActivas(estudianteId, sesionAExcluir);
		if (activas.size() >= MAX_INSCRIPCIONES_ACTIVAS) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Ya tienes el máximo de tres tutorías inscritas. Cancela una para inscribirte en otra.");
		}
		validarCruceHorario(ventana, activas);
	}

	/** Valida solo el cruce de horario (sin contar el cupo máximo). */
	public void validarConflictoActual(String estudianteId, VentanaHorario ventana, String sesionAExcluir) {
		validarCruceHorario(ventana, sesionesActivas(estudianteId, sesionAExcluir));
	}

	private List<SesionTutoria> sesionesActivas(String estudianteId, String sesionAExcluir) {
		LocalDateTime ahora = LocalDateTime.now();
		return sesiones.findByEstudianteIdsContaining(estudianteId).stream()
				.filter(sesion -> !sesion.id().equals(sesionAExcluir))
				.filter(sesion -> sesion.fechaFin().isAfter(ahora))
				.toList();
	}

	private void validarCruceHorario(VentanaHorario ventana, List<SesionTutoria> activas) {
		boolean hayCruce = activas.stream()
				.anyMatch(sesion -> ventana.seCruzaCon(new VentanaHorario(sesion.fechaInicio(), sesion.fechaFin())));
		if (hayCruce) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El horario se cruza con otra tutoría que ya tienes inscrita.");
		}
	}
}
