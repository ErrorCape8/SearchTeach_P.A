package com.pa.searchteach.dashboard.service;

import java.text.Normalizer;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import weka.classifiers.functions.Logistic;
import weka.core.Attribute;
import weka.core.DenseInstance;
import weka.core.Instance;
import weka.core.Instances;
import weka.core.SerializationHelper;

/**
 * Predice cuántos grupos nuevos de Proyecto de Aula se formarán en la semana por carrera
 * con el modelo Weka Logistic {@code models/pa_grupos.model} (relación pa_grupos_semanales).
 *
 * <p>Atributos: carrera (nominal), semana_del_anio, nuevos_semana_anterior,
 * promedio_ultimas_3_semanas, estudiantes_sin_grupo (numéricos) y clase grupos_nuevos
 * (0, 1, 2, 3_o_mas). Las categorías se leen de la cabecera del modelo.
 */
@Service
public class PaGruposLogisticService {

	private static final Logger LOGGER = LoggerFactory.getLogger(PaGruposLogisticService.class);
	private static final String MODEL_PATH = "models/pa_grupos.model";
	private static final Pattern DIACRITICAL_MARKS = Pattern.compile("\\p{M}+");

	private volatile Modelo modelo;

	@PostConstruct
	void cargarModelo() {
		try (var input = new ClassPathResource(MODEL_PATH).getInputStream()) {
			Object[] objetos = SerializationHelper.readAll(input);
			if (objetos.length < 2 || !(objetos[0] instanceof Logistic) || !(objetos[1] instanceof Instances)) {
				throw new IllegalStateException(
						"El archivo debe contener un Weka Logistic y su cabecera (Instances).");
			}
			modelo = Modelo.desde((Logistic) objetos[0], (Instances) objetos[1]);
			LOGGER.info("Modelo Weka Logistic de grupos PA cargado desde {} ({} carreras).",
					MODEL_PATH, modelo.carreras().size());
		} catch (Exception exception) {
			modelo = null;
			LOGGER.error("No se pudo cargar el modelo Weka de grupos PA desde {}.", MODEL_PATH, exception);
		}
	}

	public boolean isAvailable() {
		return modelo != null;
	}

	public Optional<Prediction> predecir(
			String carrera,
			int semanaDelAnio,
			double nuevosSemanaAnterior,
			double promedioUltimas3Semanas,
			double estudiantesSinGrupos) {
		Modelo actual = modelo;
		if (actual == null || carrera == null) {
			return Optional.empty();
		}
		String categoria = actual.carreras().get(normalizar(carrera));
		if (categoria == null) {
			return Optional.empty();
		}
		Instances header = actual.header();
		Instance instance = new DenseInstance(header.numAttributes());
		instance.setDataset(header);
		instance.setValue(header.attribute("carrera"), categoria);
		instance.setValue(header.attribute("semana_del_anio"), semanaDelAnio);
		instance.setValue(header.attribute("nuevos_semana_anterior"), nuevosSemanaAnterior);
		instance.setValue(header.attribute("promedio_ultimas_3_semanas"), promedioUltimas3Semanas);
		instance.setValue(header.attribute("estudiantes_sin_grupo"), estudiantesSinGrupos);
		instance.setMissing(header.classIndex());

		double[] distribucion;
		try {
			synchronized (actual.logistic()) {
				distribucion = actual.logistic().distributionForInstance(instance);
			}
		} catch (Exception exception) {
			throw new IllegalStateException("No se pudo clasificar con el modelo de grupos PA.", exception);
		}
		Attribute clase = header.classAttribute();
		if (distribucion.length != clase.numValues()) {
			throw new IllegalStateException("El modelo de grupos PA devolvió una distribución inválida.");
		}
		Map<String, Double> probabilidades = new LinkedHashMap<>();
		int mejor = 0;
		for (int i = 0; i < distribucion.length; i++) {
			if (!Double.isFinite(distribucion[i])) {
				throw new IllegalStateException("El modelo de grupos PA devolvió una probabilidad inválida.");
			}
			probabilidades.put(clase.value(i), distribucion[i]);
			if (distribucion[i] > distribucion[mejor]) {
				mejor = i;
			}
		}
		return Optional.of(new Prediction(clase.value(mejor), distribucion[mejor], probabilidades));
	}

	private static String normalizar(String value) {
		String withoutMarks = DIACRITICAL_MARKS.matcher(
				Normalizer.normalize(value, Normalizer.Form.NFD)).replaceAll("");
		return withoutMarks.trim().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
	}

	private static Attribute atributo(Instances estructura, String nombre, boolean nominal) {
		Attribute atributo = estructura.attribute(nombre);
		if (atributo == null || atributo.isNominal() != nominal) {
			throw new IllegalStateException("La cabecera del modelo no tiene el atributo '" + nombre
					+ "' como " + (nominal ? "nominal" : "numérico") + ".");
		}
		return atributo;
	}

	private record Modelo(Logistic logistic, Instances header, Map<String, String> carreras) {

		private static Modelo desde(Logistic logistic, Instances estructura) {
			Attribute carrera = atributo(estructura, "carrera", true);
			atributo(estructura, "semana_del_anio", false);
			atributo(estructura, "nuevos_semana_anterior", false);
			atributo(estructura, "promedio_ultimas_3_semanas", false);
			atributo(estructura, "estudiantes_sin_grupo", false);
			Attribute clase = atributo(estructura, "grupos_nuevos", true);
			Instances header = new Instances(estructura, 0);
			header.setClassIndex(clase.index());
			Map<String, String> categorias = new HashMap<>();
			for (int i = 0; i < carrera.numValues(); i++) {
				categorias.putIfAbsent(normalizar(carrera.value(i)), carrera.value(i));
			}
			return new Modelo(logistic, header, categorias);
		}
	}

	/** clase: "0", "1", "2" o "3_o_mas"; probabilidades: distribución por clase. */
	public record Prediction(String clase, double probabilidad, Map<String, Double> probabilidades) {
	}
}
