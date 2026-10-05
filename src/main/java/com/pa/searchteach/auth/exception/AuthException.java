package com.pa.searchteach.auth.exception;

import org.springframework.http.HttpStatus;

public class AuthException extends RuntimeException {

	private final HttpStatus status;
	private final boolean retryable;
	private final long retryAfterSeconds;

	public AuthException(HttpStatus status, String message, boolean retryable) {
		this(status, message, retryable, 0);
	}

	public AuthException(HttpStatus status, String message, boolean retryable, long retryAfterSeconds) {
		super(message);
		this.status = status;
		this.retryable = retryable;
		this.retryAfterSeconds = retryAfterSeconds;
	}

	public HttpStatus getStatus() {
		return status;
	}

	public boolean isRetryable() {
		return retryable;
	}

	public long getRetryAfterSeconds() {
		return retryAfterSeconds;
	}
}
