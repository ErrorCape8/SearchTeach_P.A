package com.pa.searchteach.tutorias.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Pattern;
import java.util.List;
import com.pa.searchteach.tutorias.model.MateriaHorario;

public record HorarioTutorSolicitud(
		@NotBlank String carrera,
		@Positive int semestre,
		@NotBlank String dia,
		@NotBlank @Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$") String horaInicio,
		@NotBlank @Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$") String horaFin,
		@NotBlank String modalidad,
		String ubicacion,
		List<MateriaHorario> materias) {
}
