package com.pa.searchteach.common.exception;

import com.pa.searchteach.auth.exception.AuthException;
import org.springframework.http.HttpStatus;
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
		String message = switch (field) {
			case "identifier" -> "La identificación debe tener entre 6 y 10 dígitos numéricos.";
			case "password" -> "La contraseña debe tener entre 8 y 72 caracteres.";
			case "studentId" -> "El identificador del estudiante es obligatorio.";
			case "teacherId" -> "El identificador del docente es obligatorio.";
			case "startDate" -> "La fecha de inicio es obligatoria.";
			case "endDate" -> "La fecha de finalización es obligatoria.";
			case "status" -> "El estado de la tutoría es obligatorio.";
			default -> "La solicitud contiene un campo obligatorio inválido.";
		};
		return ResponseEntity.badRequest().body(new ApiError(message, true, 0));
	}

	@ExceptionHandler(IllegalArgumentException.class)
	ResponseEntity<ApiError> handleInvalidInput(IllegalArgumentException exception) {
		return ResponseEntity.badRequest().body(new ApiError(exception.getMessage(), false, 0));
	}

	@ExceptionHandler(NotFoundException.class)
	ResponseEntity<ApiError> handleNotFound(NotFoundException exception) {
		return ResponseEntity.status(HttpStatus.NOT_FOUND)
				.body(new ApiError(exception.getMessage(), false, 0));
	}

	@ExceptionHandler(ForbiddenException.class)
	ResponseEntity<ApiError> handleForbidden(ForbiddenException exception) {
		return ResponseEntity.status(HttpStatus.FORBIDDEN)
				.body(new ApiError(exception.getMessage(), false, 0));
	}

	public record ApiError(String message, boolean retryable, long retryAfterSeconds) {
	}
}
