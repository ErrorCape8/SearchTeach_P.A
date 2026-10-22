package com.pa.searchteach.tutorias.dto;

import java.util.List;

import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.model.ProyectoAula;

public record ProyectoAulaConAvance(
		ProyectoAula proyecto,
		List<InformeAvanceProyecto> informes,
		PronosticoMejoraProyecto pronosticoMejora) {
}
