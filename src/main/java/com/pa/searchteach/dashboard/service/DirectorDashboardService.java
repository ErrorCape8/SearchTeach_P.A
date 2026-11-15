package com.pa.searchteach.dashboard.service;

import java.io.InputStream;
import java.lang.reflect.Method;
import java.text.Normalizer;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.LongStream;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pa.searchteach.dashboard.dto.AttendanceTrainingData;
import com.pa.searchteach.dashboard.dto.DashboardSummary;
import com.pa.searchteach.dashboard.dto.PaDashboardSummary;
import com.pa.searchteach.dashboard.dto.SubjectAttendancePrediction;
import com.pa.searchteach.dashboard.dto.SubjectTutoringSummary;
import com.pa.searchteach.dashboard.dto.WeeklyAttendancePrediction;
import com.pa.searchteach.dashboard.dto.WeeklyTutoringCount;
import com.pa.searchteach.tutorias.model.AsistenciaEstudiante;
import com.pa.searchteach.tutorias.model.CatalogoTecnologias;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;

@Service
public class DirectorDashboardService {

	private static final int HISTORY_WEEKS = 10;
	private static final String ESTADO_PROGRAMADA = "PROGRAMADA";
	private static final String ESTADO_FINALIZADA = "FINALIZADA";
	private static final String MATERIA_CANONICA_PA = "Tutoría de Proyecto de Aula";
	private static final Pattern DIGITS_PATTERN = Pattern.compile("\\d+");
	private static final List<String> CATALOGO_RESOURCES = List.of(
			"materias-por-tecnologia.json",
			"catalogo-materias.json",
			"materias_por_tecnologia.json",
			"data/materias-por-tecnologia.json");

	private final SesionTutoriaRepositorio sesionesRepositorio;
	private final AsistenciaLogisticService asistenciaLogisticService;
	private final Map<String, SubjectMetadataAccumulator> catalogoMaterias;

	public DirectorDashboardService(
			SesionTutoriaRepositorio sesionesRepositorio,
			AsistenciaLogisticService asistenciaLogisticService) {
		this.sesionesRepositorio = sesionesRepositorio;
		this.asistenciaLogisticService = asistenciaLogisticService;
		this.catalogoMaterias = cargarCatalogoMaterias();
	}

	public DashboardSummary obtenerResumen() {
		List<Inscripcion> inscripciones = listarInscripciones();
		long realizadas = inscripciones.stream().filter(Inscripcion::finalizada).count();
		long programadas = inscripciones.stream().filter(Inscripcion::programada).count();
		long asistieron = inscripciones.stream()
				.filter(inscripcion -> inscripcion.finalizada() && Boolean.TRUE.equals(inscripcion.asistio()))
				.count();
		long noAsistieron = inscripciones.stream()
				.filter(inscripcion -> inscripcion.finalizada() && Boolean.FALSE.equals(inscripcion.asistio()))
				.count();
		long asistenciasRegistradas = asistieron + noAsistieron;
		Double tasaAsistencia = asistenciasRegistradas == 0
				? null
				: asistieron * 100.0 / asistenciasRegistradas;
		long sinEtiqueta = realizadas - asistenciasRegistradas;

		List<Inscripcion> inscripcionesPa = inscripciones.stream().filter(Inscripcion::esPa).toList();
		long paAsistieron = inscripcionesPa.stream()
				.filter(i -> i.finalizada() && Boolean.TRUE.equals(i.asistio()))
				.count();
		long paRegistradas = inscripcionesPa.stream()
				.filter(i -> i.finalizada() && i.asistio() != null)
				.count();
		double tasaRespaldoPa = paRegistradas > 0
				? (double) paAsistieron / paRegistradas
				: (tasaAsistencia != null ? tasaAsistencia / 100.0 : 0.75);

		AttendanceForecast attendanceForecast = obtenerPrediccionesAsistencia(inscripciones, tasaRespaldoPa);
		PaDashboardSummary resumenPa = construirResumenPa(inscripcionesPa, attendanceForecast.paAccumulator());

		return new DashboardSummary(
				inscripciones.size(),
				realizadas,
				programadas,
				tasaAsistencia,
				obtenerHistorialSemanal(inscripciones),
				obtenerResumenPorMateria(inscripciones),
				new AttendanceTrainingData(
						asistenciasRegistradas, asistieron, noAsistieron, sinEtiqueta),
				asistenciaLogisticService.isAvailable() || !inscripcionesPa.isEmpty(),
				attendanceForecast.bySubject(),
				attendanceForecast.byWeek(),
				attendanceForecast.notEvaluable(),
				resumenPa);
	}

	private PaDashboardSummary construirResumenPa(
			List<Inscripcion> inscripcionesPa,
			PredictionAccumulator paAcc) {
		long totalPa = inscripcionesPa.size();
		long realizadasPa = inscripcionesPa.stream().filter(Inscripcion::finalizada).count();
		long programadasPa = inscripcionesPa.stream().filter(Inscripcion::programada).count();
		long asistieronPa = inscripcionesPa.stream()
				.filter(i -> i.finalizada() && Boolean.TRUE.equals(i.asistio()))
				.count();
		long registradasPa = inscripcionesPa.stream()
				.filter(i -> i.finalizada() && i.asistio() != null)
				.count();
		Double tasaPa = registradasPa == 0 ? null : asistieronPa * 100.0 / registradasPa;
		Double probPromedioPa = paAcc.evaluated == 0
				? null
				: paAcc.attendanceProbabilitySum / paAcc.evaluated;

		return new PaDashboardSummary(
				totalPa,
				realizadasPa,
				programadasPa,
				tasaPa,
				paAcc.evaluated,
				paAcc.attended,
				probPromedioPa);
	}

	private List<Inscripcion> listarInscripciones() {
		List<Inscripcion> inscripciones = new ArrayList<>();
		for (SesionTutoria sesion : sesionesRepositorio.findAll()) {
			Map<String, Boolean> asistencias = new HashMap<>();
			for (AsistenciaEstudiante asistencia : sesion.asistencias()) {
				asistencias.put(asistencia.estudianteId(), asistencia.asistio());
			}
			String tecnologiaSesion = leerTextoOpcional(sesion, "tecnologia", "getTecnologia", "carrera", "programa");
			Integer semestreSesion = parsearSemestre(
					leerValorOpcional(sesion, "semestre", "getSemestre", "nivel"));
			boolean esPa = detectarSesionPa(sesion);
			String nombreMateria = esPa && !tieneMateria(sesion.materia())
					? MATERIA_CANONICA_PA
					: sesion.materia();

			for (String estudianteId : sesion.estudianteIds()) {
				inscripciones.add(new Inscripcion(
						nombreMateria,
						esPa,
						tecnologiaSesion,
						semestreSesion,
						sesion.modalidad(),
						sesion.fechaInicio(),
						sesion.estadoClase(),
						estudianteId,
						asistencias.get(estudianteId)));
			}
		}
		return inscripciones;
	}

	private static boolean detectarSesionPa(SesionTutoria sesion) {
		if (sesion == null) {
			return false;
		}
		Object flagPa = leerValorOpcional(sesion, "esProyectoAula", "isProyectoAula", "proyectoAula");
		if (flagPa instanceof Boolean b && b) {
			return true;
		}
		String proyectoId = leerTextoOpcional(sesion, "proyectoAulaId", "getProyectoAulaId", "proyectoId");
		if (proyectoId != null) {
			return true;
		}
		String tipo = leerTextoOpcional(sesion, "tipo", "getTipo", "tipoTutoria", "getTipoTutoria", "categoria");
		if (tipo != null) {
			String normTipo = normalizarTexto(tipo);
			if (normTipo.contains("proyecto de aula") || normTipo.equals("pa") || normTipo.contains("colectiva")) {
				return true;
			}
		}
		if (tieneMateria(sesion.materia())) {
			String normMateria = normalizarTexto(sesion.materia());
			return normMateria.contains("proyecto de aula")
					|| normMateria.equals("tutoria pa")
					|| normMateria.equals("pa");
		}
		return false;
	}

	private AttendanceForecast obtenerPrediccionesAsistencia(
			List<Inscripcion> inscripciones,
			double tasaRespaldoPa) {
		LocalDateTime now = LocalDateTime.now();
		List<Inscripcion> proximas = inscripciones.stream()
				.filter(Inscripcion::programada)
				.filter(inscripcion -> inscripcion.fechaInicio() != null && inscripcion.fechaInicio().isAfter(now))
				.toList();

		Map<String, PredictionAccumulator> predictions = new TreeMap<>();
		Map<LocalDate, PredictionAccumulator> predictionsByWeek = new TreeMap<>();
		PredictionAccumulator paAccumulator = new PredictionAccumulator();
		long notEvaluable = 0;

		for (Inscripcion inscripcion : proximas) {
			Optional<AsistenciaLogisticService.Prediction> prediction = Optional.empty();
			if (asistenciaLogisticService.isAvailable()) {
				prediction = asistenciaLogisticService.predecir(
						inscripcion.materia(), inscripcion.modalidad(), inscripcion.fechaInicio());
				if (prediction.isEmpty() && inscripcion.esPa()) {
					prediction = asistenciaLogisticService.predecir(
							MATERIA_CANONICA_PA, inscripcion.modalidad(), inscripcion.fechaInicio());
				}
			}

			if (prediction.isEmpty() && inscripcion.esPa()) {
				double prob = estimarProbabilidadPaRespaldo(inscripcion, tasaRespaldoPa);
				prediction = Optional.of(new AsistenciaLogisticService.Prediction(prob >= 0.5, prob));
			}

			if (prediction.isEmpty()) {
				notEvaluable++;
				continue;
			}

			String etiquetaSubject = inscripcion.esPa() ? MATERIA_CANONICA_PA : inscripcion.materia();
			predictions.computeIfAbsent(etiquetaSubject, ignored -> new PredictionAccumulator())
					.add(prediction.get());
			LocalDate week = inscripcion.fechaInicio().toLocalDate().with(DayOfWeek.MONDAY);
			predictionsByWeek.computeIfAbsent(week, ignored -> new PredictionAccumulator())
					.add(prediction.get());

			if (inscripcion.esPa()) {
				paAccumulator.add(prediction.get());
			}
		}

		List<SubjectAttendancePrediction> bySubject = predictions.entrySet().stream()
				.map(entry -> entry.getValue().toDto(entry.getKey()))
				.toList();
		List<WeeklyAttendancePrediction> byWeek = predictionsByWeek.entrySet().stream()
				.map(entry -> entry.getValue().toWeeklyDto(entry.getKey()))
				.toList();
		return new AttendanceForecast(bySubject, byWeek, notEvaluable, paAccumulator);
	}

	private static double estimarProbabilidadPaRespaldo(Inscripcion inscripcion, double baseRate) {
		double prob = Math.max(0.15, Math.min(0.95, baseRate));
		if (inscripcion.modalidad() == ModalidadTutoria.VIRTUAL) {
			prob = Math.min(0.96, prob + 0.05);
		}
		if (inscripcion.fechaInicio() != null) {
			int hour = inscripcion.fechaInicio().getHour();
			if (hour < 7 || hour >= 20) {
				prob = Math.max(0.15, prob - 0.06);
			}
		}
		return prob;
	}

	private List<SubjectTutoringSummary> obtenerResumenPorMateria(List<Inscripcion> inscripciones) {
		Map<String, List<Inscripcion>> porMateria = inscripciones.stream()
				.filter(inscripcion -> tieneMateria(inscripcion.materia()))
				.collect(Collectors.groupingBy(
						inscripcion -> inscripcion.esPa() ? MATERIA_CANONICA_PA : inscripcion.materia(),
						TreeMap::new,
						Collectors.toList()));
		return porMateria.entrySet().stream()
				.map(entry -> {
					String materia = entry.getKey();
					List<Inscripcion> items = entry.getValue();
					Set<String> estudiantes = new HashSet<>();
					Set<String> carreras = new LinkedHashSet<>();
					Set<Integer> semestres = new TreeSet<>();

					SubjectMetadataAccumulator fromCatalog = buscarEnCatalogo(materia);
					if (fromCatalog != null) {
						carreras.addAll(fromCatalog.carreras);
						semestres.addAll(fromCatalog.semestres);
					}

					for (Inscripcion item : items) {
						estudiantes.add(item.estudianteId());
						String carreraCanonica = resolverTecnologiaCanonica(item.tecnologia());
						if (carreraCanonica != null) {
							carreras.add(carreraCanonica);
						}
						if (item.semestre() != null) {
							semestres.add(item.semestre());
						}
					}

					long registradas = items.stream().filter(item -> item.asistio() != null).count();
					long confirmadas = items.stream().filter(item -> Boolean.TRUE.equals(item.asistio())).count();
					return new SubjectTutoringSummary(
							materia,
							List.copyOf(carreras),
							List.copyOf(semestres),
							items.size(),
							items.stream().filter(Inscripcion::finalizada).count(),
							estudiantes.size(),
							confirmadas,
							registradas,
							registradas == 0 ? null : confirmadas * 100.0 / registradas);
				})
				.toList();
	}

	private SubjectMetadataAccumulator buscarEnCatalogo(String materia) {
		if (catalogoMaterias.isEmpty() || !tieneMateria(materia)) {
			return null;
		}
		String claveExacta = normalizarTexto(materia);
		SubjectMetadataAccumulator direct = catalogoMaterias.get(claveExacta);
		if (direct != null) {
			return direct;
		}
		return catalogoMaterias.get(normalizarRomanoAlFinal(claveExacta));
	}

	private Map<String, SubjectMetadataAccumulator> cargarCatalogoMaterias() {
		Map<String, SubjectMetadataAccumulator> index = new HashMap<>();
		ObjectMapper mapper = new ObjectMapper();
		for (String path : CATALOGO_RESOURCES) {
			ClassPathResource resource = new ClassPathResource(path);
			if (!resource.exists()) {
				continue;
			}
			try (InputStream in = resource.getInputStream()) {
				JsonNode root = mapper.readTree(in);
				extraerDesdeJson(root, null, null, index);
				if (!index.isEmpty()) {
					break;
				}
			} catch (Exception ignored) {
			}
		}
		return index;
	}

	private void extraerDesdeJson(
			JsonNode node,
			String currentCareer,
			Integer currentSemester,
			Map<String, SubjectMetadataAccumulator> index) {
		if (node == null || node.isNull()) {
			return;
		}
		if (node.isObject()) {
			String nextCareer = currentCareer;
			Integer nextSemester = currentSemester;

			for (String careerField : List.of("tecnologia", "carrera", "programa", "nombreTecnologia")) {
				JsonNode val = node.get(careerField);
				if (val != null && val.isTextual()) {
					String resolved = resolverTecnologiaCanonica(val.asText());
					if (resolved != null) {
						nextCareer = resolved;
					}
				}
			}
			for (String semField : List.of("semestre", "nivel", "numeroSemestre")) {
				JsonNode val = node.get(semField);
				if (val != null && !val.isNull()) {
					Integer parsed = parsearSemestre(val.isNumber() ? val.asInt() : val.asText());
					if (parsed != null) {
						nextSemester = parsed;
					}
				}
			}
			for (String subjField : List.of("materia", "asignatura", "nombreMateria")) {
				JsonNode val = node.get(subjField);
				if (val != null && val.isTextual() && tieneMateria(val.asText())) {
					registrarMateria(index, val.asText(), nextCareer, nextSemester);
				}
			}

			Iterator<Map.Entry<String, JsonNode>> fields = node.fields();
			while (fields.hasNext()) {
				Map.Entry<String, JsonNode> entry = fields.next();
				String key = entry.getKey();
				JsonNode child = entry.getValue();

				String branchCareer = nextCareer;
				Integer branchSemester = nextSemester;

				String resolvedCareer = resolverTecnologiaCanonica(key);
				if (resolvedCareer != null) {
					branchCareer = resolvedCareer;
				} else {
					Integer parsedSem = parsearSemestre(key);
					if (parsedSem != null) {
						branchSemester = parsedSem;
					}
				}
				extraerDesdeJson(child, branchCareer, branchSemester, index);
			}
			return;
		}

		if (node.isArray()) {
			for (JsonNode element : node) {
				if (element.isTextual()) {
					String text = element.asText();
					if (tieneMateria(text)
							&& resolverTecnologiaCanonica(text) == null
							&& (currentCareer != null || currentSemester != null)) {
						registrarMateria(index, text, currentCareer, currentSemester);
					}
				} else {
					extraerDesdeJson(element, currentCareer, currentSemester, index);
				}
			}
		}
	}

	private static void registrarMateria(
			Map<String, SubjectMetadataAccumulator> index,
			String materia,
			String career,
			Integer semester) {
		if (career == null && semester == null) {
			return;
		}
		String key = normalizarTexto(materia);
		index.computeIfAbsent(key, ignored -> new SubjectMetadataAccumulator())
				.add(career, semester);
		String altKey = normalizarRomanoAlFinal(key);
		if (!altKey.equals(key)) {
			index.computeIfAbsent(altKey, ignored -> new SubjectMetadataAccumulator())
					.add(career, semester);
		}
	}

	private static String resolverTecnologiaCanonica(String raw) {
		if (raw == null || raw.isBlank()) {
			return null;
		}
		String norm = normalizarTexto(raw);
		for (String valor : CatalogoTecnologias.VALORES) {
			if (normalizarTexto(valor).equals(norm)) {
				return valor;
			}
		}
		return null;
	}

	private static Integer parsearSemestre(Object raw) {
		if (raw == null) {
			return null;
		}
		if (raw instanceof Number number) {
			int value = number.intValue();
			return (value >= 1 && value <= 10) ? value : null;
		}
		String clean = normalizarTexto(raw.toString()).toUpperCase(Locale.ROOT);
		if (clean.isEmpty()) {
			return null;
		}
		Matcher matcher = DIGITS_PATTERN.matcher(clean);
		if (matcher.find()) {
			int value = Integer.parseInt(matcher.group());
			return (value >= 1 && value <= 10) ? value : null;
		}
		String token = clean.replace("SEMESTRE", "").trim();
		return switch (token) {
			case "I" -> 1;
			case "II" -> 2;
			case "III" -> 3;
			case "IV" -> 4;
			case "V" -> 5;
			case "VI" -> 6;
			case "VII" -> 7;
			case "VIII" -> 8;
			case "IX" -> 9;
			case "X" -> 10;
			default -> null;
		};
	}

	private static String normalizarTexto(String text) {
		String decomposed = Normalizer.normalize(text.trim(), Normalizer.Form.NFD);
		return decomposed
				.replaceAll("\\p{M}", "")
				.toLowerCase(Locale.ROOT)
				.replaceAll("\\s+", " ");
	}

	private static String normalizarRomanoAlFinal(String normalizedSubject) {
		if (normalizedSubject.endsWith(" viii")) return normalizedSubject.substring(0, normalizedSubject.length() - 5) + " 8";
		if (normalizedSubject.endsWith(" vii")) return normalizedSubject.substring(0, normalizedSubject.length() - 4) + " 7";
		if (normalizedSubject.endsWith(" iii")) return normalizedSubject.substring(0, normalizedSubject.length() - 4) + " 3";
		if (normalizedSubject.endsWith(" vi")) return normalizedSubject.substring(0, normalizedSubject.length() - 3) + " 6";
		if (normalizedSubject.endsWith(" iv")) return normalizedSubject.substring(0, normalizedSubject.length() - 3) + " 4";
		if (normalizedSubject.endsWith(" ix")) return normalizedSubject.substring(0, normalizedSubject.length() - 3) + " 9";
		if (normalizedSubject.endsWith(" ii")) return normalizedSubject.substring(0, normalizedSubject.length() - 3) + " 2";
		if (normalizedSubject.endsWith(" v")) return normalizedSubject.substring(0, normalizedSubject.length() - 2) + " 5";
		if (normalizedSubject.endsWith(" x")) return normalizedSubject.substring(0, normalizedSubject.length() - 2) + " 10";
		if (normalizedSubject.endsWith(" i")) return normalizedSubject.substring(0, normalizedSubject.length() - 2) + " 1";
		return normalizedSubject;
	}

	private static String leerTextoOpcional(Object target, String... methodNames) {
		Object value = leerValorOpcional(target, methodNames);
		return value instanceof String s && !s.isBlank() ? s : null;
	}

	private static Object leerValorOpcional(Object target, String... methodNames) {
		if (target == null) {
			return null;
		}
		Class<?> type = target.getClass();
		for (String name : methodNames) {
			try {
				Method method = type.getMethod(name);
				Object value = method.invoke(target);
				if (value != null) {
					return value;
				}
			} catch (ReflectiveOperationException ignored) {
			}
		}
		return null;
	}

	private List<WeeklyTutoringCount> obtenerHistorialSemanal(List<Inscripcion> inscripciones) {
		LocalDate currentWeek = LocalDate.now().with(DayOfWeek.MONDAY);
		LocalDate firstWeek = currentWeek.minusWeeks(HISTORY_WEEKS - 1);

		Map<LocalDate, Long> countsByWeek = new HashMap<>();
		for (Inscripcion inscripcion : inscripciones) {
			if (inscripcion.fechaInicio() == null) {
				continue;
			}
			LocalDate week = inscripcion.fechaInicio().toLocalDate().with(DayOfWeek.MONDAY);
			if (!week.isBefore(firstWeek) && !week.isAfter(currentWeek)) {
				countsByWeek.merge(week, 1L, Long::sum);
			}
		}
		return LongStream.range(0, HISTORY_WEEKS)
				.mapToObj(offset -> {
					LocalDate week = firstWeek.plusWeeks(offset);
					return new WeeklyTutoringCount(week, countsByWeek.getOrDefault(week, 0L));
				})
				.toList();
	}

	private static boolean tieneMateria(String materia) {
		return materia != null && !materia.isBlank();
	}

	private record Inscripcion(
			String materia,
			boolean esPa,
			String tecnologia,
			Integer semestre,
			ModalidadTutoria modalidad,
			LocalDateTime fechaInicio,
			String estado,
			String estudianteId,
			Boolean asistio) {

		private boolean finalizada() {
			return ESTADO_FINALIZADA.equals(estado);
		}

		private boolean programada() {
			return ESTADO_PROGRAMADA.equals(estado);
		}
	}

	private static final class SubjectMetadataAccumulator {
		private final Set<String> carreras = new LinkedHashSet<>();
		private final Set<Integer> semestres = new TreeSet<>();

		private void add(String career, Integer semester) {
			if (career != null) carreras.add(career);
			if (semester != null) semestres.add(semester);
		}
	}

	private record AttendanceForecast(
			List<SubjectAttendancePrediction> bySubject,
			List<WeeklyAttendancePrediction> byWeek,
			long notEvaluable,
			PredictionAccumulator paAccumulator) {
	}

	private static final class PredictionAccumulator {
		private long evaluated;
		private long attended;
		private double attendanceProbabilitySum;

		private void add(AsistenciaLogisticService.Prediction prediction) {
			evaluated++;
			if (prediction.asistenciaPredicha()) {
				attended++;
			}
			attendanceProbabilitySum += prediction.probabilidadAsistencia();
		}

		private WeeklyAttendancePrediction toWeeklyDto(LocalDate semanaInicio) {
			return new WeeklyAttendancePrediction(
					semanaInicio,
					evaluated,
					attended,
					evaluated - attended,
					attendanceProbabilitySum / evaluated);
		}

		private SubjectAttendancePrediction toDto(String materia) {
			return new SubjectAttendancePrediction(
					materia,
					evaluated,
					attended,
					evaluated - attended,
					attendanceProbabilitySum / evaluated);
		}
	}
}
