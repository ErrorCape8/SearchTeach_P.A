package com.pa.searchteach.calidad.dto;

public record RegistrarCalificacionRequest(
		String sesionId,
		String estudianteId,
		String tutorId,
		String materia,
		int estrellas,
		String comentario) {
}
