package com.pa.searchteach.tutorias.model;

import java.io.IOException;
import java.io.InputStream;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;

public final class CatalogoMateriasTecnologia {

	private static final Map<String, Map<String, List<String>>> MATERIAS = cargar();

	private CatalogoMateriasTecnologia() {
	}

	public static List<MateriaHorario> listar(String tecnologia, int semestre) {
		if (semestre < 1 || semestre > 6) {
			throw new IllegalArgumentException("El semestre debe estar entre 1 y 6.");
		}
		String tecnologiaCanonica = buscarTecnologia(tecnologia);
		List<String> materias = MATERIAS.get(tecnologiaCanonica).get(Integer.toString(semestre));
		return materias.stream()
				.map(nombre -> new MateriaHorario(nombre, carrerasPara(nombre)))
				.toList();
	}

	public static boolean contiene(String tecnologia, int semestre, String materia) {
		if (materia == null || semestre < 1 || semestre > 6) {
			return false;
		}
		String tecnologiaCanonica;
		try {
			tecnologiaCanonica = buscarTecnologia(tecnologia);
		} catch (IllegalArgumentException exception) {
			return false;
		}
		String nombreNormalizado = normalizar(materia);
		return MATERIAS.get(tecnologiaCanonica).get(Integer.toString(semestre)).stream()
				.anyMatch(nombre -> normalizar(nombre).equals(nombreNormalizado));
	}

	public static List<String> carrerasPara(String materia) {
		String nombreNormalizado = normalizar(materia);
		List<String> carreras = new ArrayList<>();
		for (String tecnologia : CatalogoTecnologias.VALORES) {
			boolean existeEnTecnologia = MATERIAS.get(tecnologia).values().stream()
					.flatMap(List::stream)
					.anyMatch(nombre -> normalizar(nombre).equals(nombreNormalizado));
			if (existeEnTecnologia) {
				carreras.add(tecnologia);
			}
		}
		return List.copyOf(carreras);
	}

	public static String normalizar(String valor) {
		return Normalizer.normalize(valor == null ? "" : valor, Normalizer.Form.NFD)
				.replaceAll("\\p{M}", "")
				.toLowerCase(Locale.ROOT)
				.replaceAll("[^a-z0-9]+", " ")
				.trim();
	}

	private static String buscarTecnologia(String tecnologia) {
		String normalizada = normalizar(tecnologia);
		return CatalogoTecnologias.VALORES.stream()
				.filter(valor -> normalizar(valor).equals(normalizada))
				.findFirst()
				.orElseThrow(() -> new IllegalArgumentException(
						"Selecciona una tecnología del catálogo institucional."));
	}

	private static Map<String, Map<String, List<String>>> cargar() {
		try (InputStream stream = new ClassPathResource("materias-por-tecnologia.json").getInputStream()) {
			Map<String, Map<String, List<String>>> materias = new ObjectMapper().readValue(
					stream,
					new TypeReference<Map<String, Map<String, List<String>>>>() {
					});
			for (String tecnologia : CatalogoTecnologias.VALORES) {
				Map<String, List<String>> semestres = materias.get(tecnologia);
				if (semestres == null
						|| java.util.stream.IntStream.rangeClosed(1, 6)
								.anyMatch(semestre -> semestres.get(Integer.toString(semestre)) == null
										|| semestres.get(Integer.toString(semestre)).isEmpty())) {
					throw new IllegalStateException(
							"El plan de estudios está incompleto para " + tecnologia + ".");
				}
			}
			return Map.copyOf(materias);
		} catch (IOException exception) {
			throw new ExceptionInInitializerError(exception);
		}
	}
}
