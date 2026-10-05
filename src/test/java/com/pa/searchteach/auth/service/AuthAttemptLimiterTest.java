package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.exception.AuthException;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.http.HttpStatus;

import java.time.Duration;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class AuthAttemptLimiterTest {

	@Test
	void locksAnIdentificationAfterFiveFailedAttempts() {
		StringRedisTemplate redisTemplate = mock(StringRedisTemplate.class);
		@SuppressWarnings("unchecked")
		ValueOperations<String, String> valueOperations = mock(ValueOperations.class);
		when(redisTemplate.opsForValue()).thenReturn(valueOperations);

		Map<String, Long> counters = new HashMap<>();
		Set<String> locks = new HashSet<>();
		when(valueOperations.increment(anyString())).thenAnswer(invocation ->
				counters.merge(invocation.getArgument(0), 1L, Long::sum));
		when(redisTemplate.getExpire(anyString(), eq(TimeUnit.SECONDS))).thenAnswer(invocation ->
				locks.contains(invocation.getArgument(0)) ? 900L : -2L);
		when(redisTemplate.expire(anyString(), eq(Duration.ofSeconds(900)))).thenReturn(true);
		doAnswer(invocation -> {
			locks.add(invocation.getArgument(0));
			return null;
		}).when(valueOperations).set(anyString(), eq("1"), eq(Duration.ofSeconds(900)));

		AuthAttemptLimiter limiter = new AuthAttemptLimiter(redisTemplate, 5, 20, 900);
		for (int attempt = 0; attempt < 5; attempt++) {
			limiter.recordFailure("00123456", "127.0.0.1");
		}

		AuthException exception = assertThrows(AuthException.class,
				() -> limiter.assertAllowed("00123456", "127.0.0.1"));

		assertEquals(HttpStatus.TOO_MANY_REQUESTS, exception.getStatus());
		assertEquals(900, exception.getRetryAfterSeconds());
	}
}
