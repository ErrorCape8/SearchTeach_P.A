package com.pa.searchteach.dashboard.service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Collectors;
import java.util.stream.LongStream;

import com.pa.searchteach.dashboard.dto.AttendanceTrainingData;
import com.pa.searchteach.dashboard.dto.DashboardSummary;
import com.pa.searchteach.dashboard.dto.SubjectAttendancePrediction;
import com.pa.searchteach.dashboard.dto.SubjectTutoringSummary;
import com.pa.searchteach.dashboard.dto.WeeklyAttendancePrediction;
import com.pa.searchteach.dashboard.dto.WeeklyTutoringCount;
import com.pa.searchteach.tutorias.model.AsistenciaEstudiante;
import com.pa.searchteach.tutorias.model.ModalidadTutoria;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import org.springframework.stereotype.Service;

/**
 * Estadísticas del dashboard de dirección.
 *
 * <p>Cada inscripción de un estudiante en una sesión cuenta como una "tutoría":
 * es la misma unidad con la que se entrenó el modelo de asistencia.
 */
@Service
public class DirectorDashboardService {

	private static final int HISTORY_WEEKS = 10;
	private static final String ESTADO_PROGRAMADA = "PROGRAMADA";
	private static final String ESTADO_FINALIZADA = "FINALIZADA";
	private final SesionTutoriaRepositorio sesionesRepositorio;
	private final AsistenciaLogisticService asistenciaLogisticService;

	public DirectorDashboardService(
			SesionTutoriaRepositorio sesionesRepositorio,
			AsistenciaLogisticService asistenciaLogisticService) {
		this.sesionesRepositorio = sesionesRepositorio;
		this.asistenciaLogisticService = asistenciaLogisticService;
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
		AttendanceForecast attendanceForecast = obtenerPrediccionesAsistencia(inscripciones);

		return new DashboardSummary(
				inscripciones.size(),
				realizadas,
				programadas,
				tasaAsistencia,
				obtenerHistorialSemanal(inscripciones),
				obtenerResumenPorMateria(inscripciones),
				new AttendanceTrainingData(
						asistenciasRegistradas, asistieron, noAsistieron, sinEtiqueta),
				asistenciaLogisticService.isAvailable(),
				attendanceForecast.bySubject(),
				attendanceForecast.byWeek(),
				attendanceForecast.notEvaluable());
	}

	private List<Inscripcion> listarInscripciones() {
		List<Inscripcion> inscripciones = new ArrayList<>();
		for (SesionTutoria sesion : sesionesRepositorio.findAll()) {
			Map<String, Boolean> asistencias = new HashMap<>();
			for (AsistenciaEstudiante asistencia : sesion.asistencias()) {
				asistencias.put(asistencia.estudianteId(), asistencia.asistio());
			}
			for (String estudianteId : sesion.estudianteIds()) {
				inscripciones.add(new Inscripcion(
						sesion.materia(),
						sesion.modalidad(),
						sesion.fechaInicio(),
						sesion.estadoClase(),
						estudianteId,
						asistencias.get(estudianteId)));
			}
		}
		return inscripciones;
	}

	private AttendanceForecast obtenerPrediccionesAsistencia(List<Inscripcion> inscripciones) {
		LocalDateTime now = LocalDateTime.now();
		List<Inscripcion> proximas = inscripciones.stream()
				.filter(Inscripcion::programada)
				.filter(inscripcion -> inscripcion.fechaInicio() != null && inscripcion.fechaInicio().isAfter(now))
				.toList();
		if (!asistenciaLogisticService.isAvailable()) {
			return new AttendanceForecast(List.of(), List.of(), proximas.size());
		}
		Map<String, PredictionAccumulator> predictions = new TreeMap<>();
		Map<LocalDate, PredictionAccumulator> predictionsByWeek = new TreeMap<>();
		long notEvaluable = 0;
		for (Inscripcion inscripcion : proximas) {
			var prediction = asistenciaLogisticService.predecir(
					inscripcion.materia(), inscripcion.modalidad(), inscripcion.fechaInicio());
			if (prediction.isEmpty()) {
				notEvaluable++;
				continue;
			}
			predictions.computeIfAbsent(inscripcion.materia(), ignored -> new PredictionAccumulator())
					.add(prediction.get());
			LocalDate week = inscripcion.fechaInicio().toLocalDate().with(DayOfWeek.MONDAY);
			predictionsByWeek.computeIfAbsent(week, ignored -> new PredictionAccumulator())
					.add(prediction.get());
		}
		List<SubjectAttendancePrediction> bySubject = predictions.entrySet().stream()
				.map(entry -> entry.getValue().toDto(entry.getKey()))
				.toList();
		List<WeeklyAttendancePrediction> byWeek = predictionsByWeek.entrySet().stream()
				.map(entry -> entry.getValue().toWeeklyDto(entry.getKey()))
				.toList();
		return new AttendanceForecast(bySubject, byWeek, notEvaluable);
	}

	private List<SubjectTutoringSummary> obtenerResumenPorMateria(List<Inscripcion> inscripciones) {
		Map<String, List<Inscripcion>> porMateria = inscripciones.stream()
				.filter(inscripcion -> tieneMateria(inscripcion.materia()))
				.collect(Collectors.groupingBy(Inscripcion::materia, TreeMap::new, Collectors.toList()));
		return porMateria.entrySet().stream()
				.map(entry -> {
					List<Inscripcion> items = entry.getValue();
					Set<String> estudiantes = new HashSet<>();
					items.forEach(item -> estudiantes.add(item.estudianteId()));
					long registradas = items.stream().filter(item -> item.asistio() != null).count();
					long confirmadas = items.stream().filter(item -> Boolean.TRUE.equals(item.asistio())).count();
					return new SubjectTutoringSummary(
							entry.getKey(),
							items.size(),
							items.stream().filter(Inscripcion::finalizada).count(),
							estudiantes.size(),
							confirmadas,
							registradas,
							registradas == 0 ? null : confirmadas * 100.0 / registradas);
				})
				.toList();
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

	private record AttendanceForecast(
			List<SubjectAttendancePrediction> bySubject,
			List<WeeklyAttendancePrediction> byWeek,
			long notEvaluable) {
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
