package com.pa.searchteach.calidad.service;

import java.lang.reflect.Method;
import java.text.Normalizer;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Collectors;

import com.pa.searchteach.calidad.dto.CalidadGeneralSummary;
import com.pa.searchteach.calidad.dto.CalidadGeneralSummary.CalificacionAnonimaDto;
import com.pa.searchteach.calidad.dto.CalidadGeneralSummary.ComentarioFrecuenteDto;
import com.pa.searchteach.calidad.dto.CalidadGeneralSummary.MateriaCalidadDto;
import com.pa.searchteach.calidad.dto.RegistrarCalificacionRequest;
import com.pa.searchteach.calidad.model.CalificacionTutoria;
import com.pa.searchteach.calidad.repository.CalificacionTutoriaRepositorio;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.model.ValoracionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import org.springframework.stereotype.Service;

@Service
public class DirectorCalidadService {

	private static final String MATERIA_CANONICA_PA = "Tutoría de Proyecto de Aula";

	/** Mensajes predeterminados que el estudiante puede elegir al calificar. */
	private static final Set<String> COMENTARIOS_PREDETERMINADOS = Set.of(
			"El tutor no se presentó", "El tutor no ingresó", "El tutor no explicó bien",
			"El tutor llegó tarde", "La explicación fue poco clara", "Necesité más apoyo del tutor",
			"La clase estuvo bien", "El tutor explicó lo básico", "El tutor podría mejorar",
			"El tutor explicó claramente", "Buena atención del tutor", "El tutor resolvió mis dudas",
			"Excelente explicación del tutor", "El tutor fue atento y claro", "Recomiendo a este tutor");

	private static final int MAX_COMENTARIOS_FRECUENTES = 8;

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
		return obtenerResumenCalidad(null, null);
	}

	/**
	 * @param tipo    "PA" para limitar a tutorías de proyecto de aula; null = todas.
	 * @param carrera tecnología/carrera a la que pertenece la tutoría; null = todas.
	 */
	public CalidadGeneralSummary obtenerResumenCalidad(String tipo, String carrera) {
		boolean soloPa = tipo != null && tipo.trim().equalsIgnoreCase("PA");
		String carreraNorm = carrera == null || carrera.isBlank() ? null : normalizar(carrera);

		List<RegistroCalificacion> registros = recolectarTodasLasCalificaciones().stream()
				.filter(r -> !soloPa || r.esPa())
				.filter(r -> carreraNorm == null
						|| r.tecnologias().stream().map(DirectorCalidadService::normalizar).anyMatch(carreraNorm::equals))
				.toList();

		Map<Integer, Long> distribucion = new LinkedHashMap<>();
		for (int star = 5; star >= 1; star--) {
			distribucion.put(star, 0L);
		}

		if (registros.isEmpty()) {
			return new CalidadGeneralSummary(null, 0L, distribucion, List.of(), List.of(), List.of());
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
				recientes,
				contarComentariosFrecuentes(registros));
	}

	/**
	 * Cuenta cuántas veces se eligió cada mensaje predeterminado. El comentario
	 * guardado une los mensajes elegidos con ". ", así que se separa por punto.
	 */
	private static List<ComentarioFrecuenteDto> contarComentariosFrecuentes(List<RegistroCalificacion> registros) {
		Map<String, Long> conteo = new HashMap<>();
		for (RegistroCalificacion r : registros) {
			if (r.comentario() == null || r.comentario().isBlank()) {
				continue;
			}
			for (String fragmento : r.comentario().split("\\.\\s*")) {
				String texto = fragmento.trim();
				if (COMENTARIOS_PREDETERMINADOS.contains(texto)) {
					conteo.merge(texto, 1L, Long::sum);
				}
			}
		}
		return conteo.entrySet().stream()
				.sorted(Map.Entry.<String, Long>comparingByValue().reversed()
						.thenComparing(Map.Entry.comparingByKey()))
				.limit(MAX_COMENTARIOS_FRECUENTES)
				.map(e -> new ComentarioFrecuenteDto(e.getKey(), e.getValue()))
				.toList();
	}

	/**
	 * Une las calificaciones de la colección `calificaciones_tutoria` con las
	 * valoraciones guardadas dentro de cada `SesionTutoria` (las que envía la app
	 * del estudiante a /api/tutorias/grupales/{id}/valoracion). Si una misma
	 * valoración está en ambos sitios (misma sesión y estudiante) se cuenta una vez.
	 */
	private List<RegistroCalificacion> recolectarTodasLasCalificaciones() {
		Map<String, SesionTutoria> sesiones = new HashMap<>();
		for (SesionTutoria sesion : sesionRepositorio.findAll()) {
			if (sesion.id() != null) {
				sesiones.put(sesion.id(), sesion);
			}
		}

		List<RegistroCalificacion> resultado = new ArrayList<>();
		Set<String> vistas = new HashSet<>();

		for (CalificacionTutoria c : calificacionRepositorio.findAllByOrderByFechaCreacionDesc()) {
			if (c.getEstrellas() < 1 || c.getEstrellas() > 5) {
				continue;
			}
			SesionTutoria sesion = c.getSesionId() == null ? null : sesiones.get(c.getSesionId());
			if (c.getSesionId() != null && c.getEstudianteId() != null) {
				vistas.add(c.getSesionId() + "|" + c.getEstudianteId());
			}
			boolean esPa = (sesion != null && esSesionPa(sesion)) || esMateriaPa(c.getMateria());
			resultado.add(new RegistroCalificacion(
					c.getEstrellas(),
					c.getMateria(),
					c.getComentario(),
					c.getFechaCreacion(),
					esPa,
					tecnologiasDe(sesion)));
		}

		for (SesionTutoria sesion : sesiones.values()) {
			boolean esPa = esSesionPa(sesion);
			String materia = sesion.materia() != null && !sesion.materia().isBlank()
					? sesion.materia().trim()
					: (esPa ? MATERIA_CANONICA_PA : "Tutoría académica");
			for (ValoracionTutoria v : sesion.valoraciones()) {
				if (v.estrellas() < 1 || v.estrellas() > 5) {
					continue;
				}
				if (v.estudianteId() != null && !vistas.add(sesion.id() + "|" + v.estudianteId())) {
					continue;
				}
				resultado.add(new RegistroCalificacion(
						v.estrellas(),
						materia,
						v.comentario(),
						v.creadaEn() != null ? v.creadaEn() : sesion.fechaInicio(),
						esPa,
						tecnologiasDe(sesion)));
			}
		}

		return resultado;
	}

	private static List<String> tecnologiasDe(SesionTutoria sesion) {
		if (sesion == null) {
			return List.of();
		}
		List<String> lista = new ArrayList<>(sesion.tecnologias());
		if (!lista.contains(sesion.tecnologia())) {
			lista.add(sesion.tecnologia());
		}
		return lista;
	}

	/** Misma regla que el dashboard: una tutoría es de PA según el nombre de su materia. */
	private static boolean esSesionPa(SesionTutoria sesion) {
		return esMateriaPa(sesion.materia());
	}

	private static boolean esMateriaPa(String materia) {
		if (materia == null || materia.isBlank()) {
			return false;
		}
		String norm = normalizar(materia);
		return norm.contains("proyecto de aula") || norm.equals("tutoria pa") || norm.equals("pa");
	}

	private static String normalizar(String texto) {
		return Normalizer.normalize(texto == null ? "" : texto, Normalizer.Form.NFD)
				.replaceAll("\\p{M}+", "")
				.toLowerCase()
				.trim();
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

	private record RegistroCalificacion(
			int estrellas,
			String materia,
			String comentario,
			LocalDateTime fecha,
			boolean esPa,
			List<String> tecnologias) {
	}
}
