package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "solicitudes_cambio_fecha")
public record SolicitudCambioFechaSesion(
		@Id String id,
		String sesionId,
		String docenteId,
		String docenteNombre,
		String materia,
		LocalDateTime fechaInicioOriginal,
		LocalDateTime fechaFinOriginal,
		LocalDateTime fechaInicioSolicitada,
		LocalDateTime fechaFinSolicitada,
		String motivo,
		String estado,
		String motivoDenegacion,
		LocalDateTime creadaEn) {

	public static SolicitudCambioFechaSesion pendiente(String sesionId, String docenteId,
			String docenteNombre, String materia, LocalDateTime inicioOriginal, LocalDateTime finOriginal,
			LocalDateTime inicioSolicitado, LocalDateTime finSolicitado, String motivo) {
		return new SolicitudCambioFechaSesion(null, sesionId, docenteId, docenteNombre, materia,
				inicioOriginal, finOriginal, inicioSolicitado, finSolicitado, motivo, "PENDIENTE", null,
				LocalDateTime.now());
	}

	public SolicitudCambioFechaSesion resolver(String nuevoEstado, String razon) {
		return new SolicitudCambioFechaSesion(id, sesionId, docenteId, docenteNombre, materia,
				fechaInicioOriginal, fechaFinOriginal, fechaInicioSolicitada, fechaFinSolicitada,
				motivo, nuevoEstado, razon, creadaEn);
	}
}
