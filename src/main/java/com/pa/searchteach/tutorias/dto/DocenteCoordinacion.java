package com.pa.searchteach.tutorias.dto;

public record DocenteCoordinacion(String id, String nombre, String tecnologia,
		java.util.List<com.pa.searchteach.users.model.MateriaPrincipalDocente> materiasPrincipales) {
}
