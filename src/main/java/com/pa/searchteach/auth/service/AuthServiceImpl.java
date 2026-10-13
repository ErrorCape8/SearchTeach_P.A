package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.dto.AuthResponse;
import com.pa.searchteach.auth.exception.AuthException;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.users.model.Role;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;

@Service
public class AuthServiceImpl implements AuthService {

	private final UserRepository userRepository;
	private final CoordinatorRepository coordinatorRepository;
	private final MongoTemplate mongoTemplate;
	private final PasswordEncoder passwordEncoder;
	private final JwtService jwtService;
	private final AuthAttemptLimiter attemptLimiter;

	public AuthServiceImpl(
			UserRepository userRepository,
			CoordinatorRepository coordinatorRepository,
			MongoTemplate mongoTemplate,
			PasswordEncoder passwordEncoder,
			JwtService jwtService,
			AuthAttemptLimiter attemptLimiter) {
		this.userRepository = userRepository;
		this.coordinatorRepository = coordinatorRepository;
		this.mongoTemplate = mongoTemplate;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
		this.attemptLimiter = attemptLimiter;
	}

	@Override
	public AuthResponse register(String identifier, String password, String clientIp) {
		attemptLimiter.assertAllowed(identifier, clientIp);
		validatePasswordLength(password);

		Coordinator coordinator = coordinatorRepository.findById(identifier).orElse(null);
		if (coordinator == null && !userRepository.existsById(identifier)) {
			attemptLimiter.recordFailure(identifier, clientIp);
			throw new AuthException(HttpStatus.NOT_FOUND,
					"No encontramos un usuario con esa identificación. Verifícala e inténtalo de nuevo.",
					true);
		}

		Criteria passwordNotSet = new Criteria().orOperator(
				Criteria.where("passwordHash").exists(false),
				Criteria.where("passwordHash").is(null),
				Criteria.where("passwordHash").is(""));
		Query query = Query.query(new Criteria().andOperator(
				Criteria.where("_id").is(identifier),
				passwordNotSet));
		long modifiedCount;
		if (coordinator != null) {
			modifiedCount = mongoTemplate.updateFirst(
					query, Update.update("passwordHash", passwordEncoder.encode(password)), Coordinator.class)
					.getModifiedCount();
		} else {
			modifiedCount = mongoTemplate.updateFirst(
					query, Update.update("passwordHash", passwordEncoder.encode(password)), User.class)
					.getModifiedCount();
		}
		if (modifiedCount != 1) {
			attemptLimiter.recordFailure(identifier, clientIp);
			throw new AuthException(HttpStatus.CONFLICT,
					"Esta cuenta ya tiene una contraseña. Inicia sesión para continuar.",
					false);
		}

		attemptLimiter.recordSuccess(identifier);
		return issueToken(identifier, coordinator == null ? Role.USER : Role.DIRECTOR);
	}

	@Override
	public AuthResponse login(String identifier, String password, String clientIp) {
		attemptLimiter.assertAllowed(identifier, clientIp);
		validatePasswordLength(password);

		Coordinator coordinator = coordinatorRepository.findById(identifier).orElse(null);
		User user = coordinator == null ? userRepository.findById(identifier).orElse(null) : null;
		String passwordHash;
		if (coordinator != null) {
			passwordHash = coordinator.getPasswordHash();
		} else {
			passwordHash = user == null ? null : user.getPasswordHash();
		}
		if (passwordHash == null || !passwordEncoder.matches(password, passwordHash)) {
			attemptLimiter.recordFailure(identifier, clientIp);
			throw new AuthException(HttpStatus.UNAUTHORIZED,
					"Identificación o contraseña incorrecta. Revisa los datos e inténtalo de nuevo.",
					true);
		}

		attemptLimiter.recordSuccess(identifier);
		return issueToken(identifier, coordinator == null ? Role.USER : Role.DIRECTOR);
	}

	private void validatePasswordLength(String password) {
		if (password.getBytes(StandardCharsets.UTF_8).length > 72) {
			throw new AuthException(HttpStatus.BAD_REQUEST,
					"La contraseña no puede superar 72 bytes en UTF-8.", true);
		}
	}

	private AuthResponse issueToken(String identifier, Role role) {
		return new AuthResponse(jwtService.createToken(identifier, role), "Bearer",
				jwtService.getExpirationSeconds());
	}
}
