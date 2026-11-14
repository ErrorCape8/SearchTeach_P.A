package com.pa.searchteach.tutorias.service.grupal;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.dto.grupal.ProgramarTutoriasSolicitud;
import com.pa.searchteach.tutorias.dto.horarios.VentanaHorario;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import com.pa.searchteach.tutorias.service.HorariosTutoresService;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import static com.pa.searchteach.tutorias.service.grupal.ReglasTutorias.MAX_TUTORIAS_FUTURAS_DOCENTE;
import static com.pa.searchteach.tutorias.service.grupal.ReglasTutorias.semestreValido;
import static com.pa.searchteach.tutorias.service.grupal.RelojTutorias.ahora;

/** Programación, edición y eliminación de sesiones grupales por coordinación. */
@Service
public class ProgramacionSesionesService {

	private final SesionTutoriaRepositorio sesiones;
	private final HorariosTutoresService horarios;
	private final InscripcionesTutoriasEstudianteService inscripcionesEstudiante;
	private final NotificationService notificationService;
	private final ActualizacionesTutoriasService actualizacionesTutorias;

	public ProgramacionSesionesService(
			SesionTutoriaRepositorio sesiones,
			HorariosTutoresService horarios,
			InscripcionesTutoriasEstudianteService inscripcionesEstudiante,
			NotificationService notificationService,
			ActualizacionesTutoriasService actualizacionesTutorias) {
		this.sesiones = sesiones;
		this.horarios = horarios;
		this.inscripcionesEstudiante = inscripcionesEstudiante;
		this.notificationService = notificationService;
		this.actualizacionesTutorias = actualizacionesTutorias;
	}

	public List<SesionTutoria> programar(ProgramarTutoriasSolicitud solicitud) {
		if (!CatalogoTecnologias.contiene(solicitud.tecnologia())
				|| !semestreValido(solicitud.semestre())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"Selecciona una tecnología y semestre válidos.");
		}
		List<SesionTutoria> existentes = sesiones.findAll();
		List<SesionTutoria> nuevas = new ArrayList<>();
		LocalDateTime ahora = ahora();
		for (ProgramarTutoriasSolicitud.Bloque bloque : solicitud.bloques()) {
			if (bloque.modalidad() != ModalidadTutoria.VIRTUAL
					&& (bloque.ubicacion() == null || bloque.ubicacion().isBlank())) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"Indica el lugar físico para las tutorías presenciales o híbridas.");
			}
			if (bloque.fechaInicio() == null || bloque.fechaFin() == null
					|| !bloque.fechaFin().isAfter(bloque.fechaInicio())
					|| !bloque.fechaInicio().toLocalDate().equals(bloque.fechaFin().toLocalDate())
					|| !bloque.fechaInicio().isAfter(ahora)) {
				throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
						"La hora de inicio debe ser futura y la duración debe ser válida.");
			}
			horarios.validarDocenteParaTecnologia(bloque.docenteId(), solicitud.tecnologia(),
					solicitud.semestre(), bloque.materia());
			long tutoriasFuturas = existentes.stream()
					.filter(sesion -> sesion.docenteId().equals(bloque.docenteId()))
					.filter(sesion -> sesion.fechaFin().isAfter(ahora))
					.count()
					+ nuevas.stream()
							.filter(sesion -> sesion.docenteId().equals(bloque.docenteId()))
							.count();
			if (tutoriasFuturas >= MAX_TUTORIAS_FUTURAS_DOCENTE) {
				throw new ResponseStatusException(HttpStatus.CONFLICT,
						"El docente ya alcanzó el máximo de tres tutorías futuras.");
			}
			boolean conflictoExistente = existentes.stream()
					.anyMatch(sesion -> sesion.docenteId().equals(bloque.docenteId())
							&& bloque.fechaInicio().isBefore(sesion.fechaFin())
							&& sesion.fechaInicio().isBefore(bloque.fechaFin()));
			boolean conflictoNuevo = nuevas.stream()
					.anyMatch(sesion -> sesion.docenteId().equals(bloque.docenteId())
							&& bloque.fechaInicio().isBefore(sesion.fechaFin())
							&& sesion.fechaInicio().isBefore(bloque.fechaFin()));
			if (conflictoExistente || conflictoNuevo) {
				throw new ResponseStatusException(HttpStatus.CONFLICT,
						"El docente ya tiene una tutoría programada en ese horario.");
			}
			nuevas.add(SesionTutoria.crearDisponible(bloque.docenteId(), bloque.fechaInicio(),
					bloque.fechaFin(), bloque.materia(), solicitud.tecnologia(), solicitud.semestre(),
					bloque.modalidad(), bloque.ubicacion() == null ? null : bloque.ubicacion().trim()));
		}
		List<SesionTutoria> guardadas = sesiones.saveAll(nuevas);
		guardadas.forEach(sesion -> notificationService.notifyUser(
				sesion.docenteId(),
				"Nueva tutoría programada",
				"Coordinación programó una tutoría de " + sesion.materia() + " para " + sesion.tecnologia() + ".",
				"/docente"));
		guardadas.forEach(sesion -> actualizacionesTutorias.publicar("PROGRAMADA", sesion.id()));
		return guardadas;
	}

	public SesionTutoria editarPublicada(String sesionId, ProgramarTutoriasSolicitud solicitud) {
		SesionTutoria actual = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		if (solicitud.bloques().size() != 1) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Edita una tutoría a la vez.");
		}
		if (!actual.fechaInicio().isAfter(ahora())) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "No puedes editar una tutoría que ya comenzó.");
		}
		ProgramarTutoriasSolicitud.Bloque bloque = solicitud.bloques().get(0);
		if (!CatalogoTecnologias.contiene(solicitud.tecnologia()) || !semestreValido(solicitud.semestre())
				|| bloque.fechaInicio() == null || bloque.fechaFin() == null
				|| !bloque.fechaInicio().isAfter(ahora()) || !bloque.fechaFin().isAfter(bloque.fechaInicio())
				|| !bloque.fechaInicio().toLocalDate().equals(bloque.fechaFin().toLocalDate())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Selecciona una fecha futura y un horario válido.");
		}
		if (bloque.modalidad() != ModalidadTutoria.VIRTUAL && (bloque.ubicacion() == null || bloque.ubicacion().isBlank())) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Indica el lugar de la tutoría.");
		}
		horarios.validarDocenteParaTecnologia(bloque.docenteId(), solicitud.tecnologia(), solicitud.semestre(), bloque.materia());
		boolean conflicto = sesiones.findByDocenteId(bloque.docenteId()).stream()
				.filter(otra -> !otra.id().equals(sesionId))
				.anyMatch(otra -> bloque.fechaInicio().isBefore(otra.fechaFin()) && otra.fechaInicio().isBefore(bloque.fechaFin()));
		if (conflicto) throw new ResponseStatusException(HttpStatus.CONFLICT, "El docente ya tiene una tutoría en ese horario.");
		for (String estudianteId : actual.estudianteIds()) {
			inscripcionesEstudiante.validarConflictoActual(estudianteId,
					new VentanaHorario(bloque.fechaInicio(), bloque.fechaFin()), sesionId);
		}
		SesionTutoria actualizada = sesiones.save(new SesionTutoria(actual.id(), bloque.docenteId(), actual.estudianteIds(),
				bloque.fechaInicio(), bloque.fechaFin(), solicitud.tecnologia(), solicitud.semestre(), actual.asistencias(),
				bloque.materia().trim(), List.of(solicitud.tecnologia()), bloque.modalidad(),
				bloque.ubicacion() == null ? null : bloque.ubicacion().trim(), actual.estadoClase(),
				actual.motivoCierre(), actual.finalizadaEn(), actual.historialChat(), actual.valoraciones()));
		actualizacionesTutorias.publicar("REPROGRAMADA", actualizada.id());
		return actualizada;
	}

	public void eliminarPublicada(String sesionId) {
		SesionTutoria sesion = sesiones.findById(sesionId)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "No se encontró la tutoría."));
		sesiones.delete(sesion);
		actualizacionesTutorias.publicar("ELIMINADA", sesionId);
		for (String estudianteId : sesion.estudianteIds()) {
			notificationService.notifyUser(estudianteId, "Tutoría cancelada",
					"La tutoría de " + sesion.materia() + " fue cancelada por coordinación.", "/estudiante");
		}
		notificationService.notifyUser(sesion.docenteId(), "Tutoría cancelada",
				"La tutoría de " + sesion.materia() + " fue cancelada por coordinación.", "/docente");
	}
}
