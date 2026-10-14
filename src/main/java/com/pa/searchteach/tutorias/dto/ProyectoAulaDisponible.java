package com.pa.searchteach.tutorias.dto;

public record ProyectoAulaDisponible(
		String tutoriaColectivaId,
		String proyectoId,
		String nombre,
		String docenteResponsableId,
		String tecnologia,
		int semestre,
		int estudiantesInscritos,
		boolean inscrito) {
}
