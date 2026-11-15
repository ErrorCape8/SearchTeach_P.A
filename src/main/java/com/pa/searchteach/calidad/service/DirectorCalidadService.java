package com.pa.searchteach.calidad.service;

import java.lang.reflect.Method;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.stream.Collectors;

import com.pa.searchteach.calidad.dto.CalidadGeneralSummary;
import com.pa.searchteach.calidad.dto.CalidadGeneralSummary.CalificacionAnonimaDto;
import com.pa.searchteach.calidad.dto.CalidadGeneralSummary.MateriaCalidadDto;
import com.pa.searchteach.calidad.dto.RegistrarCalificacionRequest;
import com.pa.searchteach.calidad.model.CalificacionTutoria;
import com.pa.searchteach.calidad.repository.CalificacionTutoriaRepositorio;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import org.springframework.stereotype.Service;

@Service
public class DirectorCalidadService {

	private final CalificacionTutoriaRepositorio calificacionRepositorio;
	private final SesionTutoriaRepositorio sesionRepositorio;

	public DirectorCalidadService(
			CalificacionTutoriaRepositorio calificacionRepositorio,
			SesionTutoriaRepositorio sesionRepositorio) {
		this.calificacionRepositorio = calificacionRepositorio;
		this.sesionRepositorio = sesionRepositorio;
	}

	public CalificacionTutoria registrarCalificacion(RegistrarCalificacionRequest req) {
		if (req.estrellas() < 1 || req.estrellas() > 5) {
			throw new IllegalArgumentException("La calificación debe estar entre 1 y 5 estrellas.");
		}
		if (req.sesionId() == null || req.sesionId().isBlank()) {
			throw new IllegalArgumentException("El identificador de la sesión es obligatorio.");
		}

		String materia = req.materia();
		String tutorId = req.tutorId();
		if ((materia == null || materia.isBlank()) || (tutorId == null || tutorId.isBlank())) {
			SesionTutoria sesion = sesionRepositorio.findById(req.sesionId()).orElse(null);
			if (sesion != null) {
				if (materia == null || materia.isBlank()) {
					materia = sesion.materia();
				}
				if (tutorId == null || tutorId.isBlank()) {
					Object t = leerCampo(sesion, "tutorId", "getTutorId");
					if (t != null) {
						tutorId = t.toString();
					}
				}
			}
		}

		CalificacionTutoria entity = (req.estudianteId() != null && !req.estudianteId().isBlank())
				? calificacionRepositorio
						.findBySesionIdAndEstudianteId(req.sesionId(), req.estudianteId())
						.orElseGet(CalificacionTutoria::new)
				: new CalificacionTutoria();

		entity.setSesionId(req.sesionId());
		entity.setEstudianteId(req.estudianteId());
		entity.setTutorId(tutorId);
		entity.setMateria(materia != null && !materia.isBlank() ? materia.trim() : "Tutoría académica");
		entity.setEstrellas(req.estrellas());
		entity.setComentario(req.comentario() != null ? req.comentario().trim() : null);
		entity.setFechaCreacion(LocalDateTime.now());

		return calificacionRepositorio.save(entity);
	}

	public CalidadGeneralSummary obtenerResumenCalidad() {
		List<RegistroCalificacion> registros = recolectarTodasLasCalificaciones();

		Map<Integer, Long> distribucion = new LinkedHashMap<>();
		for (int star = 5; star >= 1; star--) {
			distribucion.put(star, 0L);
		}

		if (registros.isEmpty()) {
			return new CalidadGeneralSummary(null, 0L, distribucion, List.of(), List.of());
		}

		long total = registros.size();
		long sumaEstrellas = 0L;
		for (RegistroCalificacion reg : registros) {
			int stars = Math.max(1, Math.min(5, reg.estrellas()));
			sumaEstrellas += stars;
			distribucion.merge(stars, 1L, Long::sum);
		}

		double promedioGeneral = Math.round((sumaEstrellas * 10.0) / total) / 10.0;

		Map<String, List<RegistroCalificacion>> porMateria = registros.stream()
				.filter(r -> r.materia() != null && !r.materia().isBlank())
				.collect(Collectors.groupingBy(
						r -> r.materia().trim(),
						TreeMap::new,
						Collectors.toList()));

		List<MateriaCalidadDto> materiasDto = porMateria.entrySet().stream()
				.map(entry -> {
					List<RegistroCalificacion> list = entry.getValue();
					double avg = list.stream().mapToInt(RegistroCalificacion::estrellas).average().orElse(0.0);
					double rounded = Math.round(avg * 10.0) / 10.0;
					return new MateriaCalidadDto(entry.getKey(), rounded, list.size());
				})
				.toList();

		List<CalificacionAnonimaDto> recientes = registros.stream()
				.filter(r -> r.comentario() != null && !r.comentario().isBlank())
				.sorted(Comparator.comparing(
						RegistroCalificacion::fecha,
						Comparator.nullsLast(Comparator.reverseOrder())))
				.limit(10)
				.map(r -> new CalificacionAnonimaDto(
						r.estrellas(),
						r.materia(),
						r.comentario(),
						r.fecha()))
				.toList();

		return new CalidadGeneralSummary(
				promedioGeneral,
				total,
				distribucion,
				materiasDto,
				recientes);
	}

	/**
	 * Lee tanto la colección dedicada `calificaciones_tutoria` como cualquier
	 * calificación embebida dentro de `SesionTutoria` para no perder votos previos.
	 */
	private List<RegistroCalificacion> recolectarTodasLasCalificaciones() {
		List<RegistroCalificacion> resultado = new ArrayList<>();

		for (CalificacionTutoria c : calificacionRepositorio.findAllByOrderByFechaCreacionDesc()) {
			if (c.getEstrellas() >= 1 && c.getEstrellas() <= 5) {
				resultado.add(new RegistroCalificacion(
						c.getEstrellas(),
						c.getMateria(),
						c.getComentario(),
						c.getFechaCreacion()));
			}
		}

		if (resultado.isEmpty()) {
			for (SesionTutoria sesion : sesionRepositorio.findAll()) {
				Object listaEmb = leerCampo(sesion, "calificaciones", "getCalificaciones", "evaluaciones", "resenas");
				if (listaEmb instanceof Iterable<?> iterable) {
					for (Object item : iterable) {
						Integer stars = leerEntero(item, "estrellas", "getEstrellas", "puntuacion", "getPuntuacion", "rating", "calificacion");
						if (stars != null && stars >= 1 && stars <= 5) {
							String comentario = leerTexto(item, "comentario", "getComentario", "observacion");
							LocalDateTime fecha = leerFecha(item, "fecha", "getFecha", "fechaCreacion", "getFechaCreacion");
							resultado.add(new RegistroCalificacion(
									stars,
									sesion.materia(),
									comentario,
									fecha != null ? fecha : sesion.fechaInicio()));
						}
					}
				}
			}
		}

		return resultado;
	}

	private static Object leerCampo(Object target, String... names) {
		if (target == null) return null;
		for (String name : names) {
			try {
				Method m = target.getClass().getMethod(name);
				Object val = m.invoke(target);
				if (val != null) return val;
			} catch (ReflectiveOperationException ignored) {
			}
		}
		return null;
	}

	private static Integer leerEntero(Object target, String... names) {
		Object val = leerCampo(target, names);
		if (val instanceof Number n) return n.intValue();
		return null;
	}

	private static String leerTexto(Object target, String... names) {
		Object val = leerCampo(target, names);
		return val instanceof String s ? s : null;
	}

	private static LocalDateTime leerFecha(Object target, String... names) {
		Object val = leerCampo(target, names);
		return val instanceof LocalDateTime dt ? dt : null;
	}

	private record RegistroCalificacion(
			int estrellas,
			String materia,
			String comentario,
			LocalDateTime fecha) {
	}
}
