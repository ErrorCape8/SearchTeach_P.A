package com.pa.searchteach.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record LoginRequest(
		@NotBlank
		@Pattern(regexp = "[0-9]{6,10}")
		String identifier,
		@NotBlank
		@Size(min = 8, max = 72)
		String password,
		boolean rememberMe) {
	public LoginRequest(String identifier, String password) {
		this(identifier, password, false);
	}
}
