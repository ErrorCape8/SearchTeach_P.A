package com.pa.searchteach.dashboard.service;

import java.text.Normalizer;
import java.time.DayOfWeek;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.regex.Pattern;

import com.pa.searchteach.tutorias.model.Tutoria;
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

@Service
public class AsistenciaLogisticService {

	private static final Logger LOGGER = LoggerFactory.getLogger(AsistenciaLogisticService.class);
	private static final String MODEL_PATH = "models/asistencia_logistic.model";
	private static final Pattern DIACRITICAL_MARKS = Pattern.compile("\\p{M}+");
	private static final List<String> MATERIAS = List.of(
			"Programacion",
			"Estadistica",
			"Algebra Lineal",
			"Calculo Diferencial",
			"Estructuras de Datos",
			"Bases de Datos",
			"Fisica",
			"Ingles");
	private static final List<String> MODALIDADES = List.of("PRESENCIAL", "VIRTUAL");
	private static final List<String> DIAS = List.of(
			"LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SABADO");
	private static final int CLASS_INDEX = 4;
	private static final int ATTENDANCE_CLASS_INDEX = 0;

	private volatile Logistic model;

	@PostConstruct
	void cargarModelo() {
		try (var input = new ClassPathResource(MODEL_PATH).getInputStream()) {
			Object loadedModel = SerializationHelper.read(input);
			if (!(loadedModel instanceof Logistic logistic)) {
				throw new IllegalStateException("El archivo no contiene un modelo Weka Logistic.");
			}
			model = logistic;
			LOGGER.info("Modelo Weka Logistic de asistencia cargado desde {}", MODEL_PATH);
		} catch (Exception exception) {
			model = null;
			LOGGER.error("No se pudo cargar el modelo Weka de asistencia desde {}.", MODEL_PATH, exception);
		}
	}

	public boolean isAvailable() {
		return model != null;
	}

	public Optional<Prediction> predecir(Tutoria tutoria) {
		Logistic currentModel = model;
		if (currentModel == null) {
			return Optional.empty();
		}
		if (tutoria.getMateria() == null || tutoria.getModalidad() == null
				|| tutoria.getFechaInicio() == null) {
			return Optional.empty();
		}

		String materia = encontrarCategoria(tutoria.getMateria(), MATERIAS).orElse(null);
		String modalidad = encontrarCategoria(tutoria.getModalidad().name(), MODALIDADES).orElse(null);
		String dia = encontrarCategoria(nombreDia(tutoria.getFechaInicio()), DIAS).orElse(null);
		if (materia == null || modalidad == null || dia == null) {
			return Optional.empty();
		}

		Instances header = crearCabecera();
		Instance instance = new DenseInstance(header.numAttributes());
		instance.setDataset(header);
		instance.setValue(0, materia);
		instance.setValue(1, modalidad);
		instance.setValue(2, dia);
		instance.setValue(3, tutoria.getFechaInicio().getHour());
		instance.setMissing(CLASS_INDEX);

		double[] distribution;
		try {
			synchronized (currentModel) {
				distribution = currentModel.distributionForInstance(instance);
			}
		} catch (Exception exception) {
			throw new IllegalStateException("No se pudo clasificar una tutoría con el modelo de asistencia.", exception);
		}
		if (distribution.length <= ATTENDANCE_CLASS_INDEX
				|| !Double.isFinite(distribution[ATTENDANCE_CLASS_INDEX])) {
			throw new IllegalStateException("El modelo Weka devolvió una probabilidad de asistencia inválida.");
		}
		double attendanceProbability = distribution[ATTENDANCE_CLASS_INDEX];
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
			case SUNDAY -> "";
		};
	}

	private static Optional<String> encontrarCategoria(String value, List<String> categories) {
		String normalizedValue = normalizar(value);
		return categories.stream().filter(category -> normalizar(category).equals(normalizedValue)).findFirst();
	}

	private static String normalizar(String value) {
		String withoutMarks = DIACRITICAL_MARKS.matcher(
				Normalizer.normalize(value, Normalizer.Form.NFD)).replaceAll("");
		return withoutMarks.trim().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
	}

	private static Instances crearCabecera() {
		ArrayList<Attribute> attributes = new ArrayList<>(5);
		attributes.add(new Attribute("materia", MATERIAS));
		attributes.add(new Attribute("modalidad", MODALIDADES));
		attributes.add(new Attribute("dia_semana", DIAS));
		attributes.add(new Attribute("hora"));
		attributes.add(new Attribute("asistio", List.of("si", "no")));
		Instances header = new Instances("tutorias_SINTETICO_v3_completo", attributes, 0);
		header.setClassIndex(CLASS_INDEX);
		return header;
	}

	public record Prediction(boolean asistenciaPredicha, double probabilidadAsistencia) {
	}
}
