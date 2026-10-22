package com.pa.searchteach.tutorias.model;

import java.util.List;

public final class CatalogoTecnologias {
	public static final List<String> VALORES = List.of(
			"Tecnología en Automatización Electrónica Industrial",
			"Tecnología en Gestión del Talento Humano",
			"Tecnología en Gestión Contable",
			"Tecnología en Gestión Financiera",
			"Tecnología en Gestión de Negocios Internacionales",
			"Tecnología en Gestión Logística y Portuaria",
			"Tecnología en Gestión Turística y Hotelera",
			"Tecnología en Gestión de Redes de Computadores y Seguridad Informática",
			"Tecnología en Desarrollo de Software",
			"Tecnología en Seguridad e Higiene Ocupacional",
			"Tecnología en Producción Industrial",
			"Tecnología en Control de Calidad",
			"Tecnología de Plantas y Procesos Industriales",
			"Tecnología en Gestión Ambiental Industrial",
			"Tecnología en Gestión de Marketing",
			"Tecnología en Promoción Social",
			"Tecnología en Construcciones Civiles");

	private CatalogoTecnologias() {
	}

	public static boolean contiene(String tecnologia) {
		return tecnologia != null && VALORES.stream()
				.anyMatch(valor -> valor.equalsIgnoreCase(tecnologia.trim()));
	}
}
