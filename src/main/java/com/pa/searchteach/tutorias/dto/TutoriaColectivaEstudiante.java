package com.pa.searchteach.tutorias.dto;

import java.util.List;

public record TutoriaColectivaEstudiante(
		String tutoriaColectivaId,
		String tecnologia,
		int semestre,
		boolean permiteCrearProyecto,
		List<ProyectoAulaDisponible> proyectos) {
}
