package com.pa.searchteach.tutorias.dto;

import java.util.List;

import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.SesionProyectoAula;

public record ProyectoAulaSeguimientoEstudiante(
		String tutoriaColectivaId,
		String estadoTutoria,
		ProyectoAula proyecto,
		String codigoInscripcion,
		String docenteResponsable,
		List<SesionProyectoAula> sesiones) {
}
