package com.pa.searchteach.users.dto;

public record CertificacionResponse(
		String id,
		String docenteId,
		String dondeLaDio,
		String lugar,
		String duracion,
		String nombreArchivo,
		String estado,
		java.time.LocalDateTime creadaEn) {
}
