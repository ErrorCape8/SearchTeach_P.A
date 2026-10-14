package com.pa.searchteach.tutorias.dto;

import java.util.List;

import com.pa.searchteach.tutorias.modelo.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.modelo.ProyectoAula;

public record ProyectoAulaConAvance(
		ProyectoAula proyecto,
		List<InformeAvanceProyecto> informes,
		PronosticoMejoraProyecto pronosticoMejora) {
}
