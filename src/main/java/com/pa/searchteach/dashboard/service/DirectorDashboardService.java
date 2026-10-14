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

import com.pa.searchteach.dashboard.dto.DashboardSummary;
import com.pa.searchteach.dashboard.dto.PronosticoDemanda;
import com.pa.searchteach.dashboard.dto.SubjectTutoringSummary;
import com.pa.searchteach.dashboard.dto.WeeklyTutoringCount;
import com.pa.searchteach.tutorias.modelo.EstadoTutoria;
import com.pa.searchteach.tutorias.modelo.Tutoria;
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

	public DirectorDashboardService(MongoTemplate mongoTemplate) {
		this.mongoTemplate = mongoTemplate;
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

		return new DashboardSummary(
				total,
				realizadas,
				programadas,
				tasaAsistencia,
				obtenerHistorialSemanal(),
				obtenerResumenPorMateria());
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
		Map<String, PronosticoDemanda> forecasts = obtenerPronosticosPorMateria();

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
								: result.asistenciasConfirmadas() * 100.0 / result.asistenciasRegistradas(),
						forecasts.get(result.materia())))
				.toList();
	}

	private Map<String, PronosticoDemanda> obtenerPronosticosPorMateria() {
		LocalDate currentWeek = LocalDate.now().with(DayOfWeek.MONDAY);
		LocalDate firstWeek = currentWeek.minusWeeks(HISTORY_WEEKS);
		ZoneId zone = ZoneId.systemDefault();
		LocalDateTime from = firstWeek.atStartOfDay();
		LocalDateTime until = currentWeek.atStartOfDay();

		AggregationOperation match = context -> new Document(
				"$match",
				new Document("materia", new Document("$type", "string").append("$ne", ""))
						.append("fechaInicio", new Document("$gte", asDate(from, zone))
								.append("$lt", asDate(until, zone))));
		AggregationOperation project = context -> new Document(
				"$project",
				new Document("materia", 1)
						.append("day", new Document(
								"$dateToString",
								new Document("format", "%Y-%m-%d")
										.append("date", "$fechaInicio")
										.append("timezone", zone.getId()))));
		AggregationOperation group = context -> new Document(
				"$group",
				new Document("_id", new Document("materia", "$materia").append("day", "$day"))
						.append("total", new Document("$sum", 1)));
		Aggregation aggregation = Aggregation.newAggregation(match, project, group);
		List<Document> dailyCounts = mongoTemplate
				.aggregate(aggregation, "tutorias", Document.class)
				.getMappedResults();

		Map<String, Map<LocalDate, Long>> countsBySubject = new HashMap<>();
		for (Document dailyCount : dailyCounts) {
			Document key = dailyCount.get("_id", Document.class);
			LocalDate day = LocalDate.parse(key.getString("day"));
			LocalDate week = day.with(DayOfWeek.MONDAY);
			countsBySubject.computeIfAbsent(key.getString("materia"), ignored -> new TreeMap<>())
					.merge(week, dailyCount.get("total", Number.class).longValue(), Long::sum);
		}

		Map<String, PronosticoDemanda> forecasts = new HashMap<>();
		countsBySubject.forEach((subject, counts) -> {
			long weeksWithRequests = counts.values().stream().filter(total -> total > 0).count();
			if (weeksWithRequests < 4) {
				return;
			}

			LocalDate firstActiveWeek = counts.keySet().iterator().next();
			List<WeeklyTutoringCount> history = java.util.stream.LongStream.range(
					0, java.time.temporal.ChronoUnit.WEEKS.between(firstActiveWeek, currentWeek))
					.mapToObj(offset -> {
						LocalDate week = firstActiveWeek.plusWeeks(offset);
						return new WeeklyTutoringCount(week, counts.getOrDefault(week, 0L));
					})
					.toList();
			if (history.size() >= 4 && history.size() <= HISTORY_WEEKS) {
				forecasts.put(subject, RegresionDemandaSemanal.pronosticar(history));
			}
		});
		return forecasts;
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
}
