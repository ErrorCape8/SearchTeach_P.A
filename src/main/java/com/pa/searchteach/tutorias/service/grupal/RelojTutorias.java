package com.pa.searchteach.tutorias.service.grupal;

import java.time.LocalDateTime;
import java.time.ZoneId;

/** Hora actual en la zona de la institución. */
public final class RelojTutorias {

	private static final ZoneId ZONA_LOCAL = ZoneId.of("America/Bogota");

	private RelojTutorias() {
	}

	public static LocalDateTime ahora() {
		return LocalDateTime.now(ZONA_LOCAL);
	}
}
