package com.pa.searchteach.tutorias.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Positive;
import com.fasterxml.jackson.annotation.JsonIgnore;
import java.util.List;
import java.time.LocalDateTime;

public record ProyectoAula(
		String proyectoId,
		@NotBlank String nombre,
		@NotBlank String docenteResponsableId,
		@Size(max = 4) List<@NotBlank String> estudianteIds,
		@NotBlank String tecnologia,
		@Positive int semestre,
		@JsonIgnore String codigoInscripcion,
		@JsonIgnore String creadorId,
		String estadoCierre,
		String motivoCierre,
		LocalDateTime fechaReunion,
		String reunionCreadaPorId,
		String reunionSesionId,
		LocalDateTime reunionMensajePublicadoEn,
		String cierreConfirmadoPorId,
		LocalDateTime finalizadaEn,
		String descripcion) {

	public ProyectoAula(String proyectoId, String nombre, String docenteResponsableId,
			List<String> estudianteIds, String tecnologia, int semestre,
			String codigoInscripcion, String creadorId) {
		this(proyectoId, nombre, docenteResponsableId, estudianteIds, tecnologia, semestre,
				codigoInscripcion, creadorId, "EN_CURSO", null, null, null, null, null, null, null, "");
	}

	public ProyectoAula(String proyectoId, String nombre, String docenteResponsableId,
			List<String> estudianteIds, String tecnologia, int semestre, String codigoInscripcion,
			String creadorId, String estadoCierre, String motivoCierre, LocalDateTime fechaReunion,
			String reunionCreadaPorId, String reunionSesionId, LocalDateTime reunionMensajePublicadoEn,
			String cierreConfirmadoPorId, LocalDateTime finalizadaEn) {
		this(proyectoId, nombre, docenteResponsableId, estudianteIds, tecnologia, semestre,
				codigoInscripcion, creadorId, estadoCierre, motivoCierre, fechaReunion,
				reunionCreadaPorId, reunionSesionId, reunionMensajePublicadoEn,
				cierreConfirmadoPorId, finalizadaEn, "");
	}

	public ProyectoAula {
		if (proyectoId == null || proyectoId.isBlank()) {
			throw new IllegalArgumentException("El identificador del proyecto es obligatorio.");
		}
		if (nombre == null || nombre.isBlank()
				|| docenteResponsableId == null || docenteResponsableId.isBlank()
				|| tecnologia == null || tecnologia.isBlank() || semestre < 1 || semestre > 6) {
			throw new IllegalArgumentException("Los datos del proyecto deben estar completos.");
		}
		estudianteIds = estudianteIds == null ? List.of() : List.copyOf(estudianteIds);
		estadoCierre = estadoCierre == null || estadoCierre.isBlank() ? "EN_CURSO" : estadoCierre;
		if (!List.of("EN_CURSO", "PENDIENTE_CONFIRMACION", "FINALIZADO").contains(estadoCierre)) {
			throw new IllegalArgumentException("El estado de cierre del proyecto no es válido.");
		}
		if (estudianteIds.size() > 4 || estudianteIds.stream().anyMatch(id -> id == null || id.isBlank())
				|| estudianteIds.stream().distinct().count() != estudianteIds.size()) {
			throw new IllegalArgumentException("La inscripciÃ³n admite hasta cuatro estudiantes distintos.");
		}
	}

	public ProyectoAula inscribir(String estudianteId) {
		if (estudianteIds.contains(estudianteId)) return this;
		if (estudianteIds.size() >= 4) throw new IllegalArgumentException("El grupo ya tiene cuatro estudiantes.");
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId,
				java.util.stream.Stream.concat(estudianteIds.stream(), java.util.stream.Stream.of(estudianteId)).toList(),
				tecnologia, semestre, codigoInscripcion, creadorId,
				estadoCierre, motivoCierre, fechaReunion, reunionCreadaPorId, reunionSesionId,
				reunionMensajePublicadoEn, cierreConfirmadoPorId, finalizadaEn, descripcion);
	}

	public ProyectoAula desistir(String estudianteId) {
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId,
				estudianteIds.stream().filter(id -> !id.equals(estudianteId)).toList(), tecnologia, semestre,
				codigoInscripcion, creadorId, estadoCierre, motivoCierre, fechaReunion,
				reunionCreadaPorId, reunionSesionId, reunionMensajePublicadoEn, cierreConfirmadoPorId, finalizadaEn, descripcion);
	}

	public ProyectoAula programarReunion(LocalDateTime fecha, String docenteId, String sesionId) {
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId, estudianteIds, tecnologia, semestre,
				codigoInscripcion, creadorId, estadoCierre, motivoCierre, fecha, docenteId, sesionId,
				null, cierreConfirmadoPorId, finalizadaEn, descripcion);
	}

	public ProyectoAula marcarMensajeReunionPublicado(LocalDateTime fecha) {
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId, estudianteIds, tecnologia, semestre,
				codigoInscripcion, creadorId, estadoCierre, motivoCierre, fechaReunion, reunionCreadaPorId,
				reunionSesionId, fecha, cierreConfirmadoPorId, finalizadaEn, descripcion);
	}

	public ProyectoAula solicitarCierre(String motivo) {
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId, estudianteIds, tecnologia, semestre,
				codigoInscripcion, creadorId, "PENDIENTE_CONFIRMACION", motivo, fechaReunion,
				reunionCreadaPorId, reunionSesionId, reunionMensajePublicadoEn, null, null, descripcion);
	}

	public ProyectoAula confirmarCierre(String liderId, LocalDateTime fecha) {
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId, estudianteIds, tecnologia, semestre,
				codigoInscripcion, creadorId, "FINALIZADO", motivoCierre, fechaReunion,
				reunionCreadaPorId, reunionSesionId, reunionMensajePublicadoEn, liderId, fecha, descripcion);
	}

	public ProyectoAula rechazarCierre() {
		return new ProyectoAula(proyectoId, nombre, docenteResponsableId, estudianteIds, tecnologia, semestre,
				codigoInscripcion, creadorId, "EN_CURSO", null, fechaReunion,
				reunionCreadaPorId, reunionSesionId, reunionMensajePublicadoEn, null, null, descripcion);
	}
}
