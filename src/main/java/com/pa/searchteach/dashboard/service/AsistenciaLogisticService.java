package com.pa.searchteach.dashboard.service;

import java.text.Normalizer;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

import com.pa.searchteach.tutorias.model.ModalidadTutoria;
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
 * Predice la probabilidad de asistencia a una tutoría con un modelo Weka Logistic.
 *
 * <p>El archivo {@code models/asistencia.model} debe guardarse junto con su cabecera
 * (Weka Explorer o al guardar clasificador + cabecera con SerializationHelper.writeAll). Las categorías de materia,
 * modalidad y día se leen de esa cabecera, así que el modelo puede cubrir cualquier
 * catálogo de materias sin tocar este código.
 */
@Service
public class AsistenciaLogisticService {

	private static final Logger LOGGER = LoggerFactory.getLogger(AsistenciaLogisticService.class);
	private static final String MODEL_PATH = "models/asistencia.model";
	private static final Pattern DIACRITICAL_MARKS = Pattern.compile("\\p{M}+");
	private static final String CLASE_ASISTENCIA = "si";

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
			LOGGER.info("Modelo Weka Logistic de asistencia cargado desde {} ({} materias).",
					MODEL_PATH, modelo.materias().size());
		} catch (Exception exception) {
			modelo = null;
			LOGGER.error("No se pudo cargar el modelo Weka de asistencia desde {}.", MODEL_PATH, exception);
		}
	}

	public boolean isAvailable() {
		return modelo != null;
	}

	public Optional<Prediction> predecir(String materiaTutoria, ModalidadTutoria modalidadTutoria, LocalDateTime fechaInicio) {
		Modelo actual = modelo;
		if (actual == null || materiaTutoria == null || modalidadTutoria == null || fechaInicio == null) {
			return Optional.empty();
		}
		String materia = actual.materias().get(normalizar(materiaTutoria));
		String modalidad = actual.modalidades().get(normalizar(modalidadTutoria.name()));
		String dia = actual.dias().get(normalizar(nombreDia(fechaInicio)));
		if (materia == null || modalidad == null || dia == null) {
			return Optional.empty();
		}

		Instances header = actual.header();
		Instance instance = new DenseInstance(header.numAttributes());
		instance.setDataset(header);
		instance.setValue(header.attribute("materia"), materia);
		instance.setValue(header.attribute("modalidad"), modalidad);
		instance.setValue(header.attribute("dia_semana"), dia);
		instance.setValue(header.attribute("hora"), fechaInicio.getHour());
		instance.setMissing(header.classIndex());

		double[] distribution;
		try {
			synchronized (actual.logistic()) {
				distribution = actual.logistic().distributionForInstance(instance);
			}
		} catch (Exception exception) {
			throw new IllegalStateException("No se pudo clasificar una inscripción con el modelo de asistencia.", exception);
		}
		int indice = actual.claseAsistencia();
		if (distribution.length <= indice || !Double.isFinite(distribution[indice])) {
			throw new IllegalStateException("El modelo Weka devolvió una probabilidad de asistencia inválida.");
		}
		double attendanceProbability = distribution[indice];
		return Optional.of(new Prediction(attendanceProbability >= 0.5, attendanceProbability));
	}

	private static String nombreDia(LocalDateTime fecha) {
		return switch (fecha.getDayOfWeek()) {
			case MONDAY -> "LUNES";
			case TUESDAY -> "MARTES";
			case WEDNESDAY -> "MIERCOLES";
			case THURSDAY -> "JUEVES";
			case FRIDAY -> "VIERNES";
			case SATURDAY -> "SABADO";
			case SUNDAY -> "DOMINGO";
		};
	}

	private static String normalizar(String value) {
		String withoutMarks = DIACRITICAL_MARKS.matcher(
				Normalizer.normalize(value, Normalizer.Form.NFD)).replaceAll("");
		return withoutMarks.trim().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
	}

	private static Map<String, String> categorias(Attribute atributo) {
		Map<String, String> categorias = new HashMap<>();
		for (int i = 0; i < atributo.numValues(); i++) {
			categorias.putIfAbsent(normalizar(atributo.value(i)), atributo.value(i));
		}
		return categorias;
	}

	private static Attribute atributo(Instances estructura, String nombre, boolean nominal) {
		Attribute atributo = estructura.attribute(nombre);
		if (atributo == null || atributo.isNominal() != nominal) {
			throw new IllegalStateException("La cabecera del modelo no tiene el atributo '" + nombre
					+ "' como " + (nominal ? "nominal" : "numérico") + ".");
		}
		return atributo;
	}

	private record Modelo(
			Logistic logistic,
			Instances header,
			Map<String, String> materias,
			Map<String, String> modalidades,
			Map<String, String> dias,
			int claseAsistencia) {

		private static Modelo desde(Logistic logistic, Instances estructura) {
			Attribute materia = atributo(estructura, "materia", true);
			Attribute modalidad = atributo(estructura, "modalidad", true);
			Attribute dia = atributo(estructura, "dia_semana", true);
			atributo(estructura, "hora", false);
			Attribute clase = atributo(estructura, "asistio", true);
			int claseAsistencia = clase.indexOfValue(CLASE_ASISTENCIA);
			if (claseAsistencia < 0) {
				throw new IllegalStateException("La clase 'asistio' del modelo no tiene el valor '" + CLASE_ASISTENCIA + "'.");
			}
			Instances header = new Instances(estructura, 0);
			header.setClassIndex(header.attribute("asistio").index());
			return new Modelo(logistic, header, categorias(materia), categorias(modalidad), categorias(dia),
					claseAsistencia);
		}
	}

	public record Prediction(boolean asistenciaPredicha, double probabilidadAsistencia) {
	}
}
