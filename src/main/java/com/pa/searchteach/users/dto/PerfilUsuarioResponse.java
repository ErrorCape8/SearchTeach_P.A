package com.pa.searchteach.users.dto;

public record PerfilUsuarioResponse(
		String id,
		String nombre,
		String correo,
		String telefono,
		String rol,
		String carrera,
		int semestre,
		java.util.List<com.pa.searchteach.users.model.MateriaPrincipalDocente> materiasPrincipales) {
}
