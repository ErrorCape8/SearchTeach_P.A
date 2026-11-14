package com.pa.searchteach.tutorias.dto.colectivas;

public record ProyectoAulaInscripcionPreview(
		String tutoriaColectivaId,
		String proyectoId,
		String nombre,
		String descripcion,
		String creador,
		String tecnologia,
		int semestre,
		int estudiantesInscritos) {
}
