package com.pa.searchteach.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Email;

public record VerifyRegistrationRequest(
		@NotBlank @Pattern(regexp = "[0-9]{6,10}") String identifier,
		@NotBlank @Email String email) {
}
