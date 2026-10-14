package com.pa.searchteach.users.dto;

public record UserCreateRequest(
		String id,
		String nombre,
		String correo,
		String telefono,
		String rol,
		String estado,
		String carrera) {
}
