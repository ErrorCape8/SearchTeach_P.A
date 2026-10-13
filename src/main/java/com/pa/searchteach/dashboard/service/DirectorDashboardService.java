package com.pa.searchteach.dashboard.service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.pa.searchteach.dashboard.dto.DashboardSummary;
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
				obtenerHistorialSemanal());
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
}
