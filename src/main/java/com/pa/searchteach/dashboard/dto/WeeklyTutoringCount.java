package com.pa.searchteach.dashboard.dto;

import java.time.LocalDate;

public record WeeklyTutoringCount(LocalDate semanaInicio, long total) {
}
