package com.pa.searchteach.dashboard.service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

import com.pa.searchteach.dashboard.dto.AttendanceTrainingData;
import com.pa.searchteach.dashboard.dto.DashboardSummary;
import com.pa.searchteach.dashboard.dto.SubjectAttendancePrediction;
import com.pa.searchteach.dashboard.dto.SubjectTutoringSummary;
import com.pa.searchteach.dashboard.dto.WeeklyTutoringCount;
import com.pa.searchteach.tutorias.model.EstadoTutoria;
import com.pa.searchteach.tutorias.model.Tutoria;
import org.bson.Document;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.aggregation.Aggregation;
import org.springframework.data.mongodb.core.aggregation.AggregationOperation;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;

@Service
public class DirectorDashboardService {

	private static final int HISTORY_WEEKS = 10;
	private final MongoTemplate mongoTemplate;
	private final AsistenciaLogisticService asistenciaLogisticService;

	public DirectorDashboardService(
			MongoTemplate mongoTemplate,
			AsistenciaLogisticService asistenciaLogisticService) {
		this.mongoTemplate = mongoTemplate;
		this.asistenciaLogisticService = asistenciaLogisticService;
	}

	public DashboardSummary obtenerResumen() {
		long total = mongoTemplate.count(new Query(), Tutoria.class);
		long realizadas = contarPorEstado(EstadoTutoria.REALIZADA);
		long programadas = contarPorEstado(EstadoTutoria.PROGRAMADA);
		long asistieron = contarAsistencia(true);
		long noAsistieron = contarAsistencia(false);
		long asistenciasRegistradas = asistieron + noAsistieron;
		Double tasaAsistencia = asistenciasRegistradas == 0
				? null
				: asistieron * 100.0 / asistenciasRegistradas;
		long sinEtiqueta = realizadas - asistenciasRegistradas;
		AttendanceForecast attendanceForecast = obtenerPrediccionesAsistencia();

		return new DashboardSummary(
				total,
				realizadas,
				programadas,
				tasaAsistencia,
				obtenerHistorialSemanal(),
				obtenerResumenPorMateria(),
				new AttendanceTrainingData(
						asistenciasRegistradas, asistieron, noAsistieron, sinEtiqueta),
				asistenciaLogisticService.isAvailable(),
				attendanceForecast.bySubject(),
				attendanceForecast.notEvaluable());
	}

	private AttendanceForecast obtenerPrediccionesAsistencia() {
		if (!asistenciaLogisticService.isAvailable()) {
			long notEvaluable = mongoTemplate.count(
					Query.query(Criteria.where("estado").is(EstadoTutoria.PROGRAMADA)
							.and("fechaInicio").gt(LocalDateTime.now())),
					Tutoria.class);
			return new AttendanceForecast(List.of(), notEvaluable);
		}
		LocalDateTime now = LocalDateTime.now();
		List<Tutoria> tutoriasProgramadas = mongoTemplate.find(
				Query.query(Criteria.where("estado").is(EstadoTutoria.PROGRAMADA)
						.and("fechaInicio").gt(now)),
				Tutoria.class);
		Map<String, PredictionAccumulator> predictions = new TreeMap<>();
		long notEvaluable = 0;
		for (Tutoria tutoria : tutoriasProgramadas) {
			var prediction = asistenciaLogisticService.predecir(tutoria);
			if (prediction.isEmpty()) {
				notEvaluable++;
				continue;
			}
			PredictionAccumulator accumulator = predictions.computeIfAbsent(
					tutoria.getMateria(), ignored -> new PredictionAccumulator());
			accumulator.add(prediction.get());
		}
		List<SubjectAttendancePrediction> bySubject = predictions.entrySet().stream()
				.map(entry -> entry.getValue().toDto(entry.getKey()))
				.toList();
		return new AttendanceForecast(bySubject, notEvaluable);
	}

	private List<SubjectTutoringSummary> obtenerResumenPorMateria() {
		AggregationOperation match = context -> new Document(
				"$match",
				new Document("materia", new Document("$type", "string").append("$ne", "")));
		AggregationOperation group = context -> new Document(
				"$group",
				new Document("_id", "$materia")
						.append("totalTutorias", new Document("$sum", 1))
						.append("estudiantes", new Document("$addToSet", "$estudianteId"))
						.append("tutoriasRealizadas", new Document(
								"$sum",
								new Document("$cond", List.of(
										new Document("$eq", List.of("$estado", EstadoTutoria.REALIZADA.name())),
										1,
										0))))
						.append("asistenciasRegistradas", new Document(
								"$sum",
								new Document("$cond", List.of(
										new Document("$in", List.of("$asistio", List.of(true, false))),
										1,
										0))))
						.append("asistenciasConfirmadas", new Document(
								"$sum",
								new Document("$cond", List.of(
										new Document("$eq", List.of("$asistio", true)),
										1,
										0)))));
		AggregationOperation project = context -> new Document(
				"$project",
				new Document("_id", 0)
						.append("materia", "$_id")
						.append("totalTutorias", 1)
						.append("tutoriasRealizadas", 1)
						.append("estudiantesInscritos", new Document(
								"$size",
								new Document("$filter",
										new Document("input", "$estudiantes")
												.append("as", "estudiante")
												.append("cond", new Document(
														"$and",
														List.of(
																new Document("$ne", Arrays.asList("$$estudiante", null)),
																new Document("$ne", List.of("$$estudiante", ""))))))))
						.append("asistenciasConfirmadas", 1)
						.append("asistenciasRegistradas", 1));
		Aggregation aggregation = Aggregation.newAggregation(
				match,
				group,
				project,
				Aggregation.sort(org.springframework.data.domain.Sort.by("materia")));
		List<SubjectAttendanceCount> results = mongoTemplate
				.aggregate(aggregation, "tutorias", SubjectAttendanceCount.class)
				.getMappedResults();
		return results.stream()
				.map(result -> new SubjectTutoringSummary(
						result.materia(),
						result.totalTutorias(),
						result.tutoriasRealizadas(),
						result.estudiantesInscritos(),
						result.asistenciasConfirmadas(),
						result.asistenciasRegistradas(),
						result.asistenciasRegistradas() == 0
								? null
								: result.asistenciasConfirmadas() * 100.0 / result.asistenciasRegistradas()))
				.toList();
	}

	private long contarPorEstado(EstadoTutoria estado) {
		return mongoTemplate.count(
				Query.query(Criteria.where("estado").is(estado)), Tutoria.class);
	}

	private long contarAsistencia(boolean asistio) {
		Criteria criteria = Criteria.where("estado").is(EstadoTutoria.REALIZADA)
				.and("asistio").is(asistio);
		return mongoTemplate.count(Query.query(criteria), Tutoria.class);
	}

	private List<WeeklyTutoringCount> obtenerHistorialSemanal() {
		LocalDate currentWeek = LocalDate.now().with(DayOfWeek.MONDAY);
		LocalDate firstWeek = currentWeek.minusWeeks(HISTORY_WEEKS - 1);
		ZoneId zone = ZoneId.systemDefault();
		LocalDateTime from = firstWeek.atStartOfDay();
		LocalDateTime until = currentWeek.plusWeeks(1).atStartOfDay();

		AggregationOperation match = context -> new Document(
				"$match",
				new Document("fechaInicio", new Document("$gte", asDate(from, zone))
						.append("$lt", asDate(until, zone))));
		AggregationOperation projectDay = context -> new Document(
				"$project",
				new Document("day", new Document(
						"$dateToString",
						new Document("format", "%Y-%m-%d")
								.append("date", "$fechaInicio")
								.append("timezone", zone.getId()))));
		AggregationOperation groupByDay = context -> new Document(
				"$group",
				new Document("_id", "$day").append("total", new Document("$sum", 1)));

		Aggregation aggregation = Aggregation.newAggregation(
				match,
				projectDay,
				groupByDay,
				Aggregation.sort(org.springframework.data.domain.Sort.by("_id")));
		List<DailyTutoringCount> dailyCounts = mongoTemplate
				.aggregate(aggregation, "tutorias", DailyTutoringCount.class)
				.getMappedResults();

		Map<LocalDate, Long> countsByWeek = new HashMap<>();
		for (DailyTutoringCount dailyCount : dailyCounts) {
			LocalDate day = LocalDate.parse(dailyCount.id());
			LocalDate week = day.with(DayOfWeek.MONDAY);
			countsByWeek.put(week, countsByWeek.getOrDefault(week, 0L) + dailyCount.total());
		}

		return java.util.stream.LongStream.range(0, HISTORY_WEEKS)
				.mapToObj(offset -> {
					LocalDate week = firstWeek.plusWeeks(offset);
					return new WeeklyTutoringCount(week, countsByWeek.getOrDefault(week, 0L));
				})
				.toList();
	}

	private java.util.Date asDate(LocalDateTime dateTime, ZoneId zone) {
		return java.util.Date.from(dateTime.atZone(zone).toInstant());
	}

	private record DailyTutoringCount(@Id String id, long total) {
	}

	private record SubjectAttendanceCount(
			String materia,
			long totalTutorias,
			long tutoriasRealizadas,
			long estudiantesInscritos,
			long asistenciasConfirmadas,
			long asistenciasRegistradas) {
	}

	private record AttendanceForecast(
			List<SubjectAttendancePrediction> bySubject,
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
