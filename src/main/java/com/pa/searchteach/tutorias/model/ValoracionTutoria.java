package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;

public record ValoracionTutoria(
		String estudianteId,
		int estrellas,
		String comentario,
		LocalDateTime creadaEn) {
}
