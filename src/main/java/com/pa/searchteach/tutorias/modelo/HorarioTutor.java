package com.pa.searchteach.tutorias.modelo;

import java.time.LocalDateTime;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "horarios_tutores")
public record HorarioTutor(
		@Id String id,
		@NotBlank String docenteId,
		@NotBlank String carrera,
		@Positive int semestre,
		@NotBlank String dia,
		@NotBlank String horaInicio,
		@NotBlank String horaFin,
		@NotBlank String modalidad,
		String ubicacion,
		@NotNull LocalDateTime actualizadoEn) {
}
