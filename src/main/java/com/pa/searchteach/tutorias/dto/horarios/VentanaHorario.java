package com.pa.searchteach.tutorias.dto.horarios;

import java.time.LocalDateTime;

/** Intervalo de tiempo [inicio, fin) de una tutoría. */
public record VentanaHorario(LocalDateTime inicio, LocalDateTime fin) {

	public boolean seCruzaCon(VentanaHorario otra) {
		return inicio.isBefore(otra.fin) && otra.inicio.isBefore(fin);
	}
}
