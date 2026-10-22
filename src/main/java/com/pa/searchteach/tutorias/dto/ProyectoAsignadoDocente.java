package com.pa.searchteach.tutorias.dto;

import com.pa.searchteach.tutorias.model.ProyectoAula;

public record ProyectoAsignadoDocente(
		String tutoriaColectivaId,
		ProyectoAula proyecto) {
}
