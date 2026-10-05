package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.exception.AuthException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.HexFormat;
import java.util.concurrent.TimeUnit;

@Service
public class AuthAttemptLimiter {

	private static final String KEY_PREFIX = "searchteach:auth:";

	private final StringRedisTemplate redisTemplate;
	private final int maxPerIdentifier;
	private final int maxPerIp;
	private final Duration window;

	public AuthAttemptLimiter(
			StringRedisTemplate redisTemplate,
			@Value("${app.auth.attempts.max-per-identifier:5}") int maxPerIdentifier,
			@Value("${app.auth.attempts.max-per-ip:20}") int maxPerIp,
			@Value("${app.auth.attempts.window-seconds:900}") long windowSeconds) {
		if (maxPerIdentifier < 1 || maxPerIp < 1 || windowSeconds < 1) {
			throw new IllegalStateException("Authentication attempt limits and window must be positive.");
		}
		this.redisTemplate = redisTemplate;
		this.maxPerIdentifier = maxPerIdentifier;
		this.maxPerIp = maxPerIp;
		this.window = Duration.ofSeconds(windowSeconds);
	}

	public void assertAllowed(String identifier, String clientIp) {
		long retryAfter = Math.max(
				remainingSeconds(lockKey("identifier", identifier)),
				remainingSeconds(lockKey("ip", clientIp)));
		if (retryAfter > 0) {
			throw new AuthException(HttpStatus.TOO_MANY_REQUESTS,
					"Se alcanzó el límite de intentos. Vuelve a intentarlo más tarde.",
					false, retryAfter);
		}
	}

	public void recordFailure(String identifier, String clientIp) {
		increment("identifier", identifier, maxPerIdentifier);
		increment("ip", clientIp, maxPerIp);
	}

	public void recordSuccess(String identifier) {
		redisTemplate.delete(counterKey("identifier", identifier));
		redisTemplate.delete(lockKey("identifier", identifier));
	}

	private void increment(String scope, String value, int maximum) {
		String counterKey = counterKey(scope, value);
		Long count = redisTemplate.opsForValue().increment(counterKey);
		if (count == null) {
			throw new IllegalStateException("Redis did not return an authentication attempt count.");
		}
		if (count == 1 && !Boolean.TRUE.equals(redisTemplate.expire(counterKey, window))) {
			throw new IllegalStateException("Could not set the authentication attempt window in Redis.");
		}
		if (count >= maximum) {
			redisTemplate.opsForValue().set(lockKey(scope, value), "1", window);
		}
	}

	private long remainingSeconds(String key) {
		Long remaining = redisTemplate.getExpire(key, TimeUnit.SECONDS);
		if (remaining == null) {
			throw new IllegalStateException("Redis did not return an authentication lock expiration.");
		}
		if (remaining == -1) {
			throw new IllegalStateException("Authentication lock in Redis has no expiration.");
		}
		return Math.max(remaining, 0);
	}

	private String counterKey(String scope, String value) {
		return KEY_PREFIX + "attempts:" + scope + ":" + digest(value);
	}

	private String lockKey(String scope, String value) {
		return KEY_PREFIX + "lock:" + scope + ":" + digest(value);
	}

	private String digest(String value) {
		try {
			byte[] hash = MessageDigest.getInstance("SHA-256")
					.digest(value.getBytes(StandardCharsets.UTF_8));
			return HexFormat.of().formatHex(hash);
		} catch (NoSuchAlgorithmException exception) {
			throw new IllegalStateException("SHA-256 is not available.", exception);
		}
	}
}
