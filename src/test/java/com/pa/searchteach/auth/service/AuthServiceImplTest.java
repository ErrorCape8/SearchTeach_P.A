package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.dto.AuthResponse;
import com.pa.searchteach.auth.exception.AuthException;
import com.pa.searchteach.coordinators.model.Coordinator;
import com.pa.searchteach.coordinators.repository.CoordinatorRepository;
import com.pa.searchteach.programleaders.model.LiderPrograma;
import com.pa.searchteach.programleaders.repository.RepositorioLiderPrograma;
import com.pa.searchteach.users.model.Role;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.bson.Document;
import org.junit.jupiter.api.Test;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AuthServiceImplTest {

	private final UserRepository userRepository = mock(UserRepository.class);
	private final RepositorioLiderPrograma repositorioLiderPrograma = mock(RepositorioLiderPrograma.class);
	private final CoordinatorRepository coordinatorRepository = mock(CoordinatorRepository.class);
	private final MongoTemplate mongoTemplate = mock(MongoTemplate.class);
	private final PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();
	private final JwtService jwtService = new JwtService(
			"test-only-secret-key-with-at-least-32-bytes", 900);
	private final AuthAttemptLimiter attemptLimiter = mock(AuthAttemptLimiter.class);
	private final AuthServiceImpl authService = new AuthServiceImpl(
			userRepository, repositorioLiderPrograma, coordinatorRepository, mongoTemplate, passwordEncoder,
			jwtService, attemptLimiter);

	@Test
	void registrationSetsPasswordOnlyForAnExistingUnregisteredUser() {
		when(userRepository.existsById("00123456")).thenReturn(true);
		when(coordinatorRepository.findById("00123456")).thenReturn(Optional.empty());
		when(mongoTemplate.updateFirst(any(Query.class), any(Update.class), eq(User.class)))
				.thenReturn(com.mongodb.client.result.UpdateResult.acknowledged(1, 1L, null));

		AuthResponse response = authService.register("00123456", "valid-password", "127.0.0.1");

		assertEquals("Bearer", response.tokenType());
		assertEquals("00123456", jwtService.getSubject(response.token()));
		assertEquals(Role.USER, jwtService.getRole(response.token()));
		assertEquals(900, response.expiresInSeconds());
		org.mockito.ArgumentCaptor<Update> updateCaptor =
				org.mockito.ArgumentCaptor.forClass(Update.class);
		verify(mongoTemplate).updateFirst(any(Query.class), updateCaptor.capture(), eq(User.class));
		Document update = updateCaptor.getValue().getUpdateObject();
		Document set = (Document) update.get("$set");
		assertTrue(passwordEncoder.matches("valid-password", set.getString("passwordHash")));
		verify(attemptLimiter).recordSuccess("00123456");
	}

	@Test
	void registrationRejectsAnIdentificationMissingFromTheDatabase() {
		when(repositorioLiderPrograma.findById("00123456")).thenReturn(Optional.empty());
		when(userRepository.existsById("00123456")).thenReturn(false);
		when(coordinatorRepository.findById("00123456")).thenReturn(Optional.empty());

		AuthException exception = assertThrows(AuthException.class,
				() -> authService.register("00123456", "valid-password", "127.0.0.1"));

		assertEquals(HttpStatus.NOT_FOUND, exception.getStatus());
		assertTrue(exception.isRetryable());
		assertTrue(exception.getMessage().contains("Verifícala"));
		verify(attemptLimiter).recordFailure("00123456", "127.0.0.1");
		verify(mongoTemplate, never()).updateFirst(any(Query.class), any(Update.class), eq(User.class));
	}

	@Test
	void loginReturnsJwtOnlyWhenStoredPasswordMatches() {
		User user = new User();
		user.setId("00123456");
		user.setPasswordHash(passwordEncoder.encode("valid-password"));
		when(repositorioLiderPrograma.findById("00123456")).thenReturn(Optional.empty());
		when(coordinatorRepository.findById("00123456")).thenReturn(Optional.empty());
		when(userRepository.findById("00123456")).thenReturn(Optional.of(user));

		AuthResponse response = authService.login("00123456", "valid-password", "127.0.0.1");

		assertEquals("00123456", jwtService.getSubject(response.token()));
		assertEquals(Role.USER, jwtService.getRole(response.token()));
		verify(attemptLimiter).recordSuccess("00123456");
	}

	@Test
	void loginUsesOneGenericErrorForUnknownUsersAndWrongPasswords() {
		when(repositorioLiderPrograma.findById("00123456")).thenReturn(Optional.empty());
		when(userRepository.findById("00123456")).thenReturn(Optional.empty());
		when(coordinatorRepository.findById("00123456")).thenReturn(Optional.empty());

		AuthException exception = assertThrows(AuthException.class,
				() -> authService.login("00123456", "wrong-password", "127.0.0.1"));

		assertEquals(HttpStatus.UNAUTHORIZED, exception.getStatus());
		assertTrue(exception.getMessage().contains("Identificación o contraseña incorrecta"));
		verify(attemptLimiter).recordFailure("00123456", "127.0.0.1");
	}

	@Test
	void coordinatorCanRegisterAndReceivesCoordinatorRoleFromCoordinatorCollection() {
		Coordinator coordinator = new Coordinator();
		coordinator.setId("00123456");
		when(repositorioLiderPrograma.findById("00123456")).thenReturn(Optional.empty());
		when(coordinatorRepository.findById("00123456")).thenReturn(Optional.of(coordinator));
		when(mongoTemplate.updateFirst(any(Query.class), any(Update.class), eq(Coordinator.class)))
				.thenReturn(com.mongodb.client.result.UpdateResult.acknowledged(1, 1L, null));

		AuthResponse response = authService.register("00123456", "valid-password", "127.0.0.1");

		assertEquals(Role.COORDINATOR, jwtService.getRole(response.token()));
		verify(mongoTemplate).updateFirst(any(Query.class), any(Update.class), eq(Coordinator.class));
		verify(userRepository, never()).existsById("00123456");
	}

	@Test
	void coordinatorLoginUsesCredentialsFromCoordinatorCollection() {
		Coordinator coordinator = new Coordinator();
		coordinator.setId("00123456");
		coordinator.setPasswordHash(passwordEncoder.encode("valid-password"));
		when(repositorioLiderPrograma.findById("00123456")).thenReturn(Optional.empty());
		when(coordinatorRepository.findById("00123456")).thenReturn(Optional.of(coordinator));

		AuthResponse response = authService.login("00123456", "valid-password", "127.0.0.1");

		assertEquals(Role.COORDINATOR, jwtService.getRole(response.token()));
		verify(userRepository, never()).findById("00123456");
	}

	@Test
	void liderProgramaPuedeRegistrarseDesdeSuColeccion() {
		LiderPrograma liderPrograma = new LiderPrograma();
		liderPrograma.setId("00123456");
		when(repositorioLiderPrograma.findById("00123456")).thenReturn(Optional.of(liderPrograma));
		when(mongoTemplate.updateFirst(any(Query.class), any(Update.class), eq(LiderPrograma.class)))
				.thenReturn(com.mongodb.client.result.UpdateResult.acknowledged(1, 1L, null));

		AuthResponse response = authService.register("00123456", "valid-password", "127.0.0.1");

		assertEquals(Role.DIRECTOR, jwtService.getRole(response.token()));
		verify(mongoTemplate).updateFirst(any(Query.class), any(Update.class), eq(LiderPrograma.class));
		verify(coordinatorRepository, never()).findById("00123456");
		verify(userRepository, never()).existsById("00123456");
	}

	@Test
	void liderProgramaPuedeIniciarSesionDesdeSuColeccion() {
		LiderPrograma liderPrograma = new LiderPrograma();
		liderPrograma.setId("00123456");
		liderPrograma.setPasswordHash(passwordEncoder.encode("valid-password"));
		when(repositorioLiderPrograma.findById("00123456")).thenReturn(Optional.of(liderPrograma));

		AuthResponse response = authService.login("00123456", "valid-password", "127.0.0.1");

		assertEquals(Role.DIRECTOR, jwtService.getRole(response.token()));
		verify(coordinatorRepository, never()).findById("00123456");
		verify(userRepository, never()).findById("00123456");
	}
}
