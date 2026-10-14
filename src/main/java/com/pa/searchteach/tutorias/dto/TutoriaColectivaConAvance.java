package com.pa.searchteach.tutorias.dto;

import java.util.List;

import com.pa.searchteach.tutorias.modelo.TutoriaColectiva;

public record TutoriaColectivaConAvance(
		TutoriaColectiva tutoriaColectiva,
		List<ProyectoAulaConAvance> proyectos) {
}
