package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.dto.AuthResponse;
import com.pa.searchteach.auth.exception.AuthException;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.it.model.ItAdmin;
import com.pa.searchteach.it.repository.ItAdminRepository;
import com.pa.searchteach.programleaders.model.LiderPrograma;
import com.pa.searchteach.programleaders.repository.RepositorioLiderPrograma;
import com.pa.searchteach.users.model.Role;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.nio.charset.StandardCharsets;

@Service
public class AuthServiceImpl implements AuthService {

	private final UserRepository userRepository;
	private final RepositorioLiderPrograma repositorioLiderPrograma;
	private final CoordinatorRepository coordinatorRepository;
	private final ItAdminRepository itAdminRepository;
	private final MongoTemplate mongoTemplate;
	private final PasswordEncoder passwordEncoder;
	private final JwtService jwtService;
	private final AuthAttemptLimiter attemptLimiter;

	public AuthServiceImpl(
			UserRepository userRepository,
			RepositorioLiderPrograma repositorioLiderPrograma,
			CoordinatorRepository coordinatorRepository,
			MongoTemplate mongoTemplate,
			PasswordEncoder passwordEncoder,
			JwtService jwtService,
			AuthAttemptLimiter attemptLimiter) {
		this(userRepository, repositorioLiderPrograma, coordinatorRepository, null, mongoTemplate, passwordEncoder, jwtService, attemptLimiter);
	}

	@Autowired
	public AuthServiceImpl(
			UserRepository userRepository,
			RepositorioLiderPrograma repositorioLiderPrograma,
			CoordinatorRepository coordinatorRepository,
			ItAdminRepository itAdminRepository,
			MongoTemplate mongoTemplate,
			PasswordEncoder passwordEncoder,
			JwtService jwtService,
			AuthAttemptLimiter attemptLimiter) {
		this.userRepository = userRepository;
		this.repositorioLiderPrograma = repositorioLiderPrograma;
		this.coordinatorRepository = coordinatorRepository;
		this.itAdminRepository = itAdminRepository;
		this.mongoTemplate = mongoTemplate;
		this.passwordEncoder = passwordEncoder;
		this.jwtService = jwtService;
		this.attemptLimiter = attemptLimiter;
	}

	@Override
	public AuthResponse register(String identifier, String password, String clientIp) {
		attemptLimiter.assertAllowed(identifier, clientIp);
		validatePasswordLength(password);

		ItAdmin itAdmin = itAdminRepository != null
				? itAdminRepository.findById(identifier).orElse(null)
				: null;
		LiderPrograma liderPrograma = itAdmin == null
				? repositorioLiderPrograma.findById(identifier).orElse(null)
				: null;
		Coordinator legacyCoordinator = (itAdmin == null && liderPrograma == null)
				? coordinatorRepository.findById(identifier).orElse(null)
				: null;

		if (itAdmin == null && liderPrograma == null && legacyCoordinator == null && !userRepository.existsById(identifier)) {
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
		if (itAdmin != null) {
			modifiedCount = mongoTemplate.updateFirst(
					query, Update.update("passwordHash", passwordEncoder.encode(password)), ItAdmin.class)
					.getModifiedCount();
		} else if (liderPrograma != null) {
			modifiedCount = mongoTemplate.updateFirst(
					query, Update.update("passwordHash", passwordEncoder.encode(password)), LiderPrograma.class)
					.getModifiedCount();
		} else if (legacyCoordinator != null) {
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
		return issueToken(identifier, roleFor(itAdmin, liderPrograma, legacyCoordinator));
	}

	@Override
	public AuthResponse login(String identifier, String password, String clientIp) {
		attemptLimiter.assertAllowed(identifier, clientIp);
		validatePasswordLength(password);

		ItAdmin itAdmin = itAdminRepository != null
				? itAdminRepository.findById(identifier).orElse(null)
				: null;
		LiderPrograma liderPrograma = itAdmin == null
				? repositorioLiderPrograma.findById(identifier).orElse(null)
				: null;
		Coordinator legacyCoordinator = (itAdmin == null && liderPrograma == null)
				? coordinatorRepository.findById(identifier).orElse(null)
				: null;
		User user = (itAdmin == null && liderPrograma == null && legacyCoordinator == null)
				? userRepository.findById(identifier).orElse(null)
				: null;

		String passwordHash;
		if (itAdmin != null) {
			passwordHash = itAdmin.getPasswordHash();
		} else if (liderPrograma != null) {
			passwordHash = liderPrograma.getPasswordHash();
		} else if (legacyCoordinator != null) {
			passwordHash = legacyCoordinator.getPasswordHash();
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
		return issueToken(identifier, roleFor(itAdmin, liderPrograma, legacyCoordinator));
	}

	private Role roleFor(ItAdmin itAdmin, LiderPrograma liderPrograma, Coordinator legacyCoordinator) {
		if (itAdmin != null) {
			return Role.ADMIN;
		}
		if (liderPrograma != null) {
			return Role.DIRECTOR;
		}
		return legacyCoordinator != null ? Role.COORDINATOR : Role.USER;
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
