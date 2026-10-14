package com.pa.searchteach.tutorias.dto;

public record TutorDisponible(
		String docenteId,
		String nombre,
		String carrera,
		int semestre,
		String dia,
		String horaInicio,
		String horaFin,
		String modalidad,
		String ubicacion) {
}
