package com.pa.searchteach.tutorias.service.grupal;

/** Reglas de negocio compartidas por los servicios de tutorías grupales. */
public final class ReglasTutorias {

	public static final int CUPO_MAXIMO_SESION_GRUPAL = 5;
	public static final int SEMESTRE_MINIMO = 1;
	public static final int SEMESTRE_MAXIMO = 6;
	public static final int MAX_TUTORIAS_FUTURAS_DOCENTE = 3;

	private ReglasTutorias() {
	}

	public static boolean semestreValido(int semestre) {
		return semestre >= SEMESTRE_MINIMO && semestre <= SEMESTRE_MAXIMO;
	}
}
