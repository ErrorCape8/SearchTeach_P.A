package com.pa.searchteach.tutorias.dto;

import java.util.List;
import com.pa.searchteach.tutorias.modelo.MateriaHorario;

public record TutorDisponible(
		String docenteId,
		String nombre,
		String carrera,
		int semestre,
		String dia,
		String horaInicio,
		String horaFin,
		String modalidad,
		String ubicacion,
		List<String> carreras,
		List<MateriaHorario> materias) {
}
