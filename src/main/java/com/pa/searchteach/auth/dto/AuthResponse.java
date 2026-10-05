package com.pa.searchteach.auth.dto;

public record AuthResponse(String token, String tokenType, long expiresInSeconds) {
}
