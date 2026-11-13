package com.pa.searchteach.tutorias.dto;

import java.util.List;

import com.pa.searchteach.tutorias.model.ProyectoAula;

public record TutoriaColectivaLider(
		String id,
		String tecnologia,
		int semestre,
		List<DocenteAsignado> docentesApoyo,
		List<ProyectoAula> proyectos) {
	public record DocenteAsignado(String id, String nombre) {
	}
}
