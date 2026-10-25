package com.pa.searchteach.tutorias.dto;

import java.time.LocalDateTime;

import jakarta.validation.constraints.Future;
import jakarta.validation.constraints.NotNull;

public record ReunionProyectoAulaSolicitud(@NotNull @Future LocalDateTime fechaReunion) {}
