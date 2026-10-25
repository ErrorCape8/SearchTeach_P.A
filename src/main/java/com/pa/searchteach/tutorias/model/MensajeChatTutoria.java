package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;

public record MensajeChatTutoria(String usuarioId, String nombre, String texto, LocalDateTime enviadoEn) {
}
