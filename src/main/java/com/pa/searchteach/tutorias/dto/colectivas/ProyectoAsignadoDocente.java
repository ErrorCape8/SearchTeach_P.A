package com.pa.searchteach.tutorias.dto.colectivas;

import com.pa.searchteach.tutorias.model.ProyectoAula;

public record ProyectoAsignadoDocente(
		String tutoriaColectivaId,
		ProyectoAula proyecto) {
}
