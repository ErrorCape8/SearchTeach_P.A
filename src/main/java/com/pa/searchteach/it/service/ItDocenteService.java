package com.pa.searchteach.it.service;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.it.dto.AsignacionMateriasDocenteRequest;
import com.pa.searchteach.it.dto.DocenteMateriasResponse;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import java.text.Normalizer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Service;

@Service
public class ItDocenteService {

	private final UserRepository users;

	public ItDocenteService(UserRepository users) {
		this.users = users;
	}

	public List<DocenteMateriasResponse> listarDocentes() {
		return users.findAll().stream()
				.filter(this::esDocente)
				.map(this::respuesta)
				.toList();
	}

	public DocenteMateriasResponse obtener(String id) {
		return respuesta(obtenerDocente(id));
	}

	public DocenteMateriasResponse asignar(String id, AsignacionMateriasDocenteRequest request) {
		User docente = obtenerDocente(id);
		List<String> titulos = normalizarLista(request.titulosAcademicos(), "título académico");
		List<String> materias = normalizarLista(request.materiasAsignadas(), "materia");
		docente.setTitulosAcademicos(titulos);
		docente.setMateriasAsignadas(materias);
		return respuesta(users.save(docente));
	}

	private User obtenerDocente(String id) {
		User user = users.findById(id)
				.orElseThrow(() -> new NotFoundException("No se encontró el usuario docente."));
		if (!esDocente(user)) {
			throw new IllegalArgumentException("El usuario seleccionado no tiene rol de docente.");
		}
		return user;
	}

	private boolean esDocente(User user) {
		return user.getRol() != null && user.getRol().toLowerCase(Locale.ROOT).contains("docente");
	}

	private List<String> normalizarLista(List<String> valores, String campo) {
		if (valores == null || valores.isEmpty()) {
			throw new IllegalArgumentException("Asigna al menos un " + campo + ".");
		}
		LinkedHashMap<String, String> unicos = new LinkedHashMap<>();
		for (String valor : valores) {
			if (valor == null || valor.isBlank()) {
				throw new IllegalArgumentException("Los valores de " + campo + " no pueden estar vacíos.");
			}
			String limpio = valor.trim().replaceAll("\\s+", " ");
			unicos.putIfAbsent(clave(limpio), limpio);
		}
		return List.copyOf(new ArrayList<>(unicos.values()));
	}

	private String clave(String valor) {
		return Normalizer.normalize(valor, Normalizer.Form.NFD)
				.replaceAll("\\p{M}", "")
				.toLowerCase(Locale.ROOT);
	}

	private DocenteMateriasResponse respuesta(User user) {
		return new DocenteMateriasResponse(
				user.getId(),
				user.getNombre() == null ? "" : user.getNombre(),
				user.getTitulosAcademicos(),
				user.getMateriasAsignadas());
	}
}