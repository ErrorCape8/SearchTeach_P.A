package com.pa.searchteach.dashboard.service;

import java.text.Normalizer;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.IsoFields;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.regex.Pattern;

import com.pa.searchteach.dashboard.dto.PaGruposResumen;
import com.pa.searchteach.dashboard.dto.PaGruposResumen.Prediccion;
import com.pa.searchteach.dashboard.dto.PaGruposResumen.SemanaGrupos;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.tutorias.service.grupal.RelojTutorias;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.stereotype.Service;

/**
 * Arma las variables semanales por carrera (grupos nuevos de la semana anterior, promedio de las
 * últimas 3 semanas, estudiantes sin grupo y semana del año) y consulta el modelo
 * {@code pa_grupos.model} para estimar cuántos grupos nuevos se formarán la semana siguiente.
 */
@Service
public class PaGruposDashboardService {

	private static final int SEMANAS_HISTORIAL = 9;
	private static final Pattern DIACRITICAL_MARKS = Pattern.compile("\\p{M}+");

	private final TutoriaColectivaRepositorio tutoriasRepositorio;
	private final UserRepository userRepository;
	private final PaGruposLogisticService modelo;

	public PaGruposDashboardService(
			TutoriaColectivaRepositorio tutoriasRepositorio,
			UserRepository userRepository,
			PaGruposLogisticService modelo) {
		this.tutoriasRepositorio = tutoriasRepositorio;
		this.userRepository = userRepository;
		this.modelo = modelo;
	}

	public PaGruposResumen obtenerResumen() {
		LocalDateTime ahora = RelojTutorias.ahora();
		LocalDate semanaActual = ahora.toLocalDate().with(DayOfWeek.MONDAY);
		// El pronóstico es para la semana que viene; la semana en curso es su "semana anterior".
		LocalDate semanaObjetivo = semanaActual.plusWeeks(1);

		Map<String, String> nombreCarrera = new HashMap<>();
		Map<String, Map<LocalDate, Long>> nuevosPorCarrera = new HashMap<>();
		Map<String, Set<String>> estudiantesEnGrupo = new HashMap<>();

		for (TutoriaColectiva tutoria : tutoriasRepositorio.findAll()) {
			for (ProyectoAula proyecto : tutoria.proyectos()) {
				String carrera = proyecto.tecnologia();
				String clave = normalizar(carrera);
				nombreCarrera.putIfAbsent(clave, carrera);
				LocalDateTime creado = proyecto.creadoEn() != null ? proyecto.creadoEn() : tutoria.creadaEn();
				LocalDate semana = creado.toLocalDate().with(DayOfWeek.MONDAY);
				nuevosPorCarrera.computeIfAbsent(clave, k -> new HashMap<>()).merge(semana, 1L, Long::sum);
				estudiantesEnGrupo.computeIfAbsent(clave, k -> new HashSet<>()).addAll(proyecto.estudianteIds());
			}
		}

		Map<String, Set<String>> estudiantesPorCarrera = new HashMap<>();
		for (User usuario : userRepository.findAll()) {
			if (usuario.getRol() == null || !"estudiante".equals(normalizar(usuario.getRol()))
					|| usuario.getCarrera() == null || usuario.getCarrera().isBlank()
					|| (usuario.getEstado() != null && !"activo".equals(normalizar(usuario.getEstado())))) {
				continue;
			}
			String clave = normalizar(usuario.getCarrera());
			nombreCarrera.putIfAbsent(clave, usuario.getCarrera());
			estudiantesPorCarrera.computeIfAbsent(clave, k -> new HashSet<>()).add(usuario.getId());
		}

		Set<String> carreras = new TreeSet<>(nombreCarrera.keySet());
		List<SemanaGrupos> historial = new ArrayList<>();
		List<Prediccion> predicciones = new ArrayList<>();

		for (String clave : carreras) {
			String carrera = nombreCarrera.get(clave);
			Map<LocalDate, Long> semanas = nuevosPorCarrera.getOrDefault(clave, Map.of());
			Map<LocalDate, Long> ordenado = new TreeMap<>(semanas);
			for (int i = SEMANAS_HISTORIAL - 1; i >= 0; i--) {
				LocalDate semana = semanaActual.minusWeeks(i);
				historial.add(new SemanaGrupos(semana, carrera, ordenado.getOrDefault(semana, 0L)));
			}

			long anterior = semanas.getOrDefault(semanaObjetivo.minusWeeks(1), 0L);
			double promedio3 = (semanas.getOrDefault(semanaObjetivo.minusWeeks(1), 0L)
					+ semanas.getOrDefault(semanaObjetivo.minusWeeks(2), 0L)
					+ semanas.getOrDefault(semanaObjetivo.minusWeeks(3), 0L)) / 3.0;
			Set<String> alumnos = estudiantesPorCarrera.getOrDefault(clave, Set.of());
			Set<String> enGrupo = estudiantesEnGrupo.getOrDefault(clave, Set.of());
			long sinGrupo = alumnos.stream().filter(id -> !enGrupo.contains(id)).count();
			if (alumnos.isEmpty() && semanas.isEmpty()) {
				continue;
			}
			int semanaDelAnio = semanaObjetivo.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR);

			Optional<PaGruposLogisticService.Prediction> resultado =
					modelo.predecir(carrera, semanaDelAnio, anterior, promedio3, sinGrupo);
			if (resultado.isEmpty()) {
				continue;
			}
			PaGruposLogisticService.Prediction prediccion = resultado.get();
			predicciones.add(new Prediccion(carrera, semanaObjetivo, semanaDelAnio, anterior, promedio3, sinGrupo,
					prediccion.clase(), prediccion.probabilidad(), esperado(prediccion.probabilidades()),
					prediccion.probabilidades()));
		}
		return new PaGruposResumen(modelo.isAvailable(), predicciones, historial);
	}

	/** Valor esperado de grupos nuevos; la clase 3_o_mas se cuenta como 3. */
	private static double esperado(Map<String, Double> probabilidades) {
		double total = 0;
		for (Map.Entry<String, Double> entry : probabilidades.entrySet()) {
			total += valorClase(entry.getKey()) * entry.getValue();
		}
		return total;
	}

	private static int valorClase(String clase) {
		String digitos = clase.replaceAll("\\D.*$", "");
		return digitos.isEmpty() ? 0 : Integer.parseInt(digitos);
	}

	private static String normalizar(String value) {
		String sinMarcas = DIACRITICAL_MARKS.matcher(
				Normalizer.normalize(value, Normalizer.Form.NFD)).replaceAll("");
		return sinMarcas.trim().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
	}
}
