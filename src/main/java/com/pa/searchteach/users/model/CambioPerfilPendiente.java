package com.pa.searchteach.users.model;

import java.time.LocalDateTime;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "cambios_perfil_pendientes")
public record CambioPerfilPendiente(
		@Id String usuarioId,
		String codigoHash,
		String correoNuevo,
		String telefonoNuevo,
		String contrasenaHashNueva,
		int intentos,
		LocalDateTime creadoEn,
		LocalDateTime expiraEn) {
}
