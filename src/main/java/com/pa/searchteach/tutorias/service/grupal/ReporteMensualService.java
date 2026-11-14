package com.pa.searchteach.tutorias.service.grupal;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.model.ValoracionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import org.springframework.stereotype.Service;

/** Reporte mensual (CSV) de valoraciones de tutorías. */
@Service
public class ReporteMensualService {

	private final SesionTutoriaRepositorio sesiones;
	private final CoordinatorRepository coordinadores;
	private final CierreSesionesService cierre;

	public ReporteMensualService(
			SesionTutoriaRepositorio sesiones,
			CoordinatorRepository coordinadores,
			CierreSesionesService cierre) {
		this.sesiones = sesiones;
		this.coordinadores = coordinadores;
		this.cierre = cierre;
	}

	public boolean esCoordinador(String usuarioId) {
		return usuarioId != null && coordinadores.existsById(usuarioId);
	}

	public List<SesionTutoria> sesionesFinalizadasEntre(LocalDateTime inicio, LocalDateTime fin) {
		return sesiones.findAll().stream()
				.map(cierre::cerrarSiVencida)
				.filter(sesion -> "FINALIZADA".equals(sesion.estadoClase()))
				.filter(sesion -> sesion.finalizadaEn() != null
						&& !sesion.finalizadaEn().isBefore(inicio)
						&& sesion.finalizadaEn().isBefore(fin))
				.toList();
	}

	public String generarReporteMensual(LocalDateTime inicio, LocalDateTime fin) {
		List<SesionTutoria> sesionesDelMes = sesionesFinalizadasEntre(inicio, fin);
		List<ValoracionTutoria> valoraciones = sesionesDelMes.stream()
				.flatMap(sesion -> sesion.valoraciones().stream())
				.toList();
		double promedio = valoraciones.stream().mapToInt(ValoracionTutoria::estrellas)
				.average().orElse(0);
		java.util.Map<String, Long> categorias = new java.util.LinkedHashMap<>();
		categorias.put("Docente no se presento", contarCategoria(valoraciones, "no se present", "no entro", "no entró", "no asist"));
		categorias.put("Explicacion insuficiente", contarCategoria(valoraciones, "no explic", "no entiend", "explic"));
		categorias.put("Problemas de conexion", contarCategoria(valoraciones, "internet", "conexion", "conexión", "audio", "video"));
		categorias.put("Otros comentarios", Math.max(0, valoraciones.stream()
				.filter(valoracion -> !valoracion.comentario().isBlank()).count()
				- categorias.values().stream().mapToLong(Long::longValue).sum()));

		StringBuilder csv = new StringBuilder("\uFEFF");
		csv.append("REPORTE MENSUAL DE TUTORIAS\n");
		csv.append("Periodo,").append(inicio.toLocalDate()).append(" a ").append(fin.toLocalDate().minusDays(1)).append('\n');
		csv.append("Sesiones finalizadas,").append(sesionesDelMes.size()).append('\n');
		csv.append("Valoraciones recibidas,").append(valoraciones.size()).append('\n');
		csv.append("Calificacion general,").append(String.format(java.util.Locale.US, "%.2f/5", promedio)).append("\n\n");
		csv.append("Categoria,Frecuencia\n");
		categorias.forEach((categoria, cantidad) -> csv.append(escaparCsv(categoria)).append(',').append(cantidad).append('\n'));
		csv.append("\nSesion,Materia,Tutor,Estudiante,Estrellas,Comentario sobre el tutor,Fecha\n");
		for (SesionTutoria sesion : sesionesDelMes) {
			for (ValoracionTutoria valoracion : sesion.valoraciones()) {
				csv.append(escaparCsv(sesion.id())).append(',')
						.append(escaparCsv(sesion.materia())).append(',')
						.append(escaparCsv(sesion.docenteId())).append(',')
						.append(escaparCsv(valoracion.estudianteId())).append(',')
						.append(valoracion.estrellas()).append(',')
						.append(escaparCsv(valoracion.comentario())).append(',')
						.append(valoracion.creadaEn()).append('\n');
			}
		}
		return csv.toString();
	}

	private long contarCategoria(List<ValoracionTutoria> valoraciones, String... palabras) {
		return valoraciones.stream()
				.map(ValoracionTutoria::comentario)
				.filter(comentario -> {
					String normalizado = comentario.toLowerCase(java.util.Locale.ROOT);
					for (String palabra : palabras) {
						if (normalizado.contains(palabra)) return true;
					}
					return false;
				})
				.count();
	}

	private String escaparCsv(String valor) {
		String texto = valor == null ? "" : valor;
		return "\"" + texto.replace("\"", "\"\"").replace("\r", " ").replace("\n", " ") + "\"";
	}
}
