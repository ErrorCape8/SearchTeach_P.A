package com.pa.searchteach.dashboard.service;

import java.text.Normalizer;
import java.time.LocalDate;
import java.time.temporal.IsoFields;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;

import com.pa.searchteach.dashboard.dto.WeeklyTutoringCount;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import weka.classifiers.trees.REPTree;
import weka.core.Attribute;
import weka.core.DenseInstance;
import weka.core.Instance;
import weka.core.Instances;
import weka.core.SerializationHelper;

@Service
public class PronosticoReptreeService {

	private static final Logger LOGGER = LoggerFactory.getLogger(PronosticoReptreeService.class);
	private static final String MODEL_PATH = "models/reptree.model";
	private static final Pattern DIACRITICAL_MARKS = Pattern.compile("\\p{M}+");
	private static final List<String> MATERIAS = List.of(
			"Algebra_Lineal",
			"Bases_de_Datos",
			"Calculo_Diferencial",
			"Desarrollo_Web",
			"Estadistica",
			"Estructuras_de_Datos",
			"Fisica_Mecanica",
			"Ingenieria_de_Software",
			"Ingles_Tecnico",
			"Programacion_Orientada_a_Objetos",
			"Redes_de_Computadores",
			"Sistemas_Operativos");

	private volatile REPTree model;

	@PostConstruct
	void cargarModelo() {
		try (var input = new ClassPathResource(MODEL_PATH).getInputStream()) {
			Object loadedModel = SerializationHelper.read(input);
			if (!(loadedModel instanceof REPTree reptree)) {
				throw new IllegalStateException("El archivo no contiene un modelo Weka REPTree.");
			}
			model = reptree;
			LOGGER.info("Modelo Weka REPTree cargado desde {}", MODEL_PATH);
		} catch (Exception exception) {
			model = null;
			LOGGER.error("No se pudo cargar el modelo Weka REPTree desde {}; se usará la regresión.", MODEL_PATH,
					exception);
		}
	}

	public boolean isAvailable() {
		return model != null;
	}

	public Optional<List<Long>> pronosticar(
			String materia,
			List<WeeklyTutoringCount> historial,
			LocalDate primeraSemanaPronosticada) throws Exception {
		REPTree currentModel = model;
		if (currentModel == null || historial.size() < 4) {
			return Optional.empty();
		}

		String materiaNormalizada = normalizarMateria(materia);
		if (!MATERIAS.contains(materiaNormalizada)) {
			return Optional.empty();
		}

		ArrayList<Long> rezagos = new ArrayList<>(4);
		for (int offset = 1; offset <= 4; offset++) {
			rezagos.add(historial.get(historial.size() - offset).total());
		}

		Instances header = crearCabecera();
		header.setClassIndex(6);
		List<Long> predicciones = new ArrayList<>(4);
		for (int paso = 0; paso < 4; paso++) {
			LocalDate semanaPronosticada = primeraSemanaPronosticada.plusWeeks(paso);
			Instance instance = crearInstancia(
					header,
					materiaNormalizada,
					semanaPronosticada.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR),
					rezagos);
			double prediction = currentModel.classifyInstance(instance);
			if (!Double.isFinite(prediction)) {
				throw new IllegalStateException("REPTree devolvió una predicción no numérica.");
			}
			long roundedPrediction = Math.max(0, Math.round(prediction));
			predicciones.add(roundedPrediction);
			rezagos.add(0, roundedPrediction);
			rezagos.remove(4);
		}
		return Optional.of(List.copyOf(predicciones));
	}

	private static String normalizarMateria(String materia) {
		String sinTildes = DIACRITICAL_MARKS.matcher(
				Normalizer.normalize(materia, Normalizer.Form.NFD)).replaceAll("");
		return sinTildes.trim().replaceAll("\\s+", "_");
	}

	private static Instances crearCabecera() {
		ArrayList<Attribute> attributes = new ArrayList<>(7);
		attributes.add(new Attribute("materia", MATERIAS));
		attributes.add(new Attribute("semana_anio"));
		attributes.add(new Attribute("solicitudes_semana_anterior"));
		attributes.add(new Attribute("solicitudes_hace_2_semanas"));
		attributes.add(new Attribute("solicitudes_hace_3_semanas"));
		attributes.add(new Attribute("solicitudes_hace_4_semanas"));
		attributes.add(new Attribute("solicitudes"));
		return new Instances("SearchTeachDemanda", attributes, 0);
	}

	private static Instance crearInstancia(
			Instances header,
			String materia,
			int semanaAnio,
			List<Long> rezagos) {
		Instance instance = new DenseInstance(header.numAttributes());
		instance.setDataset(header);
		instance.setValue(0, materia);
		instance.setValue(1, semanaAnio);
		for (int index = 0; index < rezagos.size(); index++) {
			instance.setValue(index + 2, rezagos.get(index));
		}
		instance.setMissing(6);
		return instance;
	}
}
