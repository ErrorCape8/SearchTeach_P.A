package com.pa.searchteach.common.exception;

import com.pa.searchteach.auth.exception.AuthException;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

	@ExceptionHandler(AuthException.class)
	ResponseEntity<ApiError> handleAuthException(AuthException exception) {
		ApiError body = new ApiError(exception.getMessage(), exception.isRetryable(),
				exception.getRetryAfterSeconds());
		HttpHeaders headers = new HttpHeaders();
		if (exception.getRetryAfterSeconds() > 0) {
			headers.set(HttpHeaders.RETRY_AFTER,
					Long.toString(exception.getRetryAfterSeconds()));
		}
		return new ResponseEntity<>(body, headers, exception.getStatus());
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	ResponseEntity<ApiError> handleValidationException(MethodArgumentNotValidException exception) {
		String field = exception.getBindingResult().getFieldErrors().stream()
				.map(error -> error.getField())
				.findFirst()
				.orElse("");
		String message = "identifier".equals(field)
				? "La identificación debe tener entre 6 y 10 dígitos numéricos."
				: "La contraseña debe tener entre 8 y 72 caracteres.";
		return ResponseEntity.badRequest().body(new ApiError(message, true, 0));
	}

	public record ApiError(String message, boolean retryable, long retryAfterSeconds) {
	}
}
