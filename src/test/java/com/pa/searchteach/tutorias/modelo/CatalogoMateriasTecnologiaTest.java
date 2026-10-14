package com.pa.searchteach.tutorias.modelo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

class CatalogoMateriasTecnologiaTest {

	private static final String SOFTWARE = "Tecnología en Desarrollo de Software";
	private static final String REDES = "Tecnología en Gestión de Redes de Computadores y Seguridad Informática";

	@Test
	void comparteCiscoEntreSoftwareYRedes() {
		assertTrue(materias(SOFTWARE, 5).stream()
				.anyMatch(materia -> materia.nombre().equals("Cisco")));
		assertTrue(materias(REDES, 2).stream()
				.anyMatch(materia -> materia.nombre().equals("Cisco")));
		assertEquals(List.of(REDES, SOFTWARE), CatalogoMateriasTecnologia.carrerasPara("Cisco"));
	}

	@Test
	void comparteMateriasQueAparecenEnAmbosPlanes() {
		assertTrue(materias(SOFTWARE, 5).stream()
				.anyMatch(materia -> materia.nombre().equals("Redes de computadores")));
		assertTrue(materias(REDES, 2).stream()
				.anyMatch(materia -> materia.nombre().equals("Redes de computadores")));
		assertEquals(List.of(REDES, SOFTWARE),
				CatalogoMateriasTecnologia.carrerasPara("Redes de computadores"));
	}

	private List<MateriaHorario> materias(String tecnologia, int semestre) {
		return CatalogoMateriasTecnologia.listar(tecnologia, semestre);
	}
}
