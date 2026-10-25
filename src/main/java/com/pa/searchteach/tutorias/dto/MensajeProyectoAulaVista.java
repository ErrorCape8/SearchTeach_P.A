package com.pa.searchteach.tutorias.dto;

import java.time.LocalDateTime;

public record MensajeProyectoAulaVista(
		String id,
		String emisorId,
		boolean propio,
		String texto,
		String archivoNombre,
		String archivoMime,
		Long archivoTamano,
		LocalDateTime enviadoEn,
		String tipo,
		String reunionRoomId) {
}
