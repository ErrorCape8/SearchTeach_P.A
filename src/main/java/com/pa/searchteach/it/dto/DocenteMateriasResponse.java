package com.pa.searchteach.it.dto;

import java.util.List;

public record DocenteMateriasResponse(
		String id,
		String nombre,
		List<String> titulosAcademicos,
		List<String> materiasAsignadas) {
}