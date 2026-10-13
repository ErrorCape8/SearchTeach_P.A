package com.pa.searchteach.auth.service;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import com.pa.searchteach.users.model.Role;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;

@Service
public class JwtService {

	private final SecretKey signingKey;
	private final long expirationSeconds;

	public JwtService(
			@Value("${app.auth.jwt.secret:}") String secret,
			@Value("${app.auth.jwt.expiration-seconds:900}") long expirationSeconds) {
		if (secret.getBytes(StandardCharsets.UTF_8).length < 32) {
			throw new IllegalStateException("JWT_SECRET must contain at least 32 UTF-8 bytes.");
		}
		if (expirationSeconds <= 0) {
			throw new IllegalStateException("JWT expiration must be greater than zero.");
		}
		this.signingKey = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
		this.expirationSeconds = expirationSeconds;
	}

	public String createToken(String identifier, Role role) {
		Instant issuedAt = Instant.now();
		return Jwts.builder()
				.subject(identifier)
				.claim("role", role.name())
				.issuedAt(Date.from(issuedAt))
				.expiration(Date.from(issuedAt.plusSeconds(expirationSeconds)))
				.signWith(signingKey)
				.compact();
	}

	public String getSubject(String token) {
		return Jwts.parser()
				.verifyWith(signingKey)
				.build()
				.parseSignedClaims(token)
				.getPayload()
				.getSubject();
	}

	public Role getRole(String token) {
		String role = Jwts.parser()
				.verifyWith(signingKey)
				.build()
				.parseSignedClaims(token)
				.getPayload()
				.get("role", String.class);
		return role == null ? Role.USER : Role.valueOf(role);
	}

	public long getExpirationSeconds() {
		return expirationSeconds;
	}
}
