package com.pa.searchteach.auth.dto;

import jakarta.validation.Validation;
import jakarta.validation.Validator;
import jakarta.validation.ValidatorFactory;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class AuthRequestValidationTest {

	@Test
	void acceptsNumericIdentificationIncludingLeadingZeroes() {
		try (ValidatorFactory factory = Validation.buildDefaultValidatorFactory()) {
			Validator validator = factory.getValidator();

			assertTrue(validator.validate(new RegisterRequest("00123456", "safe-password")).isEmpty());
			assertTrue(validator.validate(new LoginRequest("1234567890", "safe-password")).isEmpty());
		}
	}

	@Test
	void rejectsIdentificationWithNonDigitsOrUnsupportedLength() {
		try (ValidatorFactory factory = Validation.buildDefaultValidatorFactory()) {
			Validator validator = factory.getValidator();

			assertFalse(validator.validate(new RegisterRequest("12345A", "safe-password")).isEmpty());
			assertFalse(validator.validate(new LoginRequest("12345", "safe-password")).isEmpty());
			assertFalse(validator.validate(new LoginRequest("12345678901", "safe-password")).isEmpty());
		}
	}
}
