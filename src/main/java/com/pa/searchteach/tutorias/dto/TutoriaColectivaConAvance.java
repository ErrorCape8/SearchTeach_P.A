package com.pa.searchteach.tutorias.dto;

import java.util.List;

import com.pa.searchteach.tutorias.model.TutoriaColectiva;

public record TutoriaColectivaConAvance(
		TutoriaColectiva tutoriaColectiva,
		List<ProyectoAulaConAvance> proyectos) {
}
