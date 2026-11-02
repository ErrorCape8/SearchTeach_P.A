package com.pa.searchteach.auth.controller;

import com.pa.searchteach.auth.dto.AuthResponse;
import com.pa.searchteach.auth.dto.LoginRequest;
import com.pa.searchteach.auth.dto.RegisterRequest;
import com.pa.searchteach.auth.dto.VerifyRegistrationRequest;
import com.pa.searchteach.auth.dto.VerifyRegistrationCodeRequest;
import com.pa.searchteach.auth.dto.ResetPasswordRequest;
import com.pa.searchteach.auth.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

	private final AuthService authService;

	public AuthController(AuthService authService) {
		this.authService = authService;
	}

	@PostMapping("/register")
	@ResponseStatus(HttpStatus.CREATED)
	public AuthResponse registrarUsuario(
			@Valid @RequestBody RegisterRequest request,
			HttpServletRequest servletRequest) {
		return authService.register(request.identifier(), request.password(), servletRequest.getRemoteAddr());
	}

	@PostMapping("/register/verify")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void verificarRegistroDeUsuario(
			@Valid @RequestBody VerifyRegistrationRequest request,
			HttpServletRequest servletRequest) {
		authService.verifyRegistration(request.identifier(), request.email(), servletRequest.getRemoteAddr());
	}

	@PostMapping("/register/verify-code")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void verificarCodigoRegistro(
			@Valid @RequestBody VerifyRegistrationCodeRequest request,
			HttpServletRequest servletRequest) {
		authService.verifyRegistrationCode(request.identifier(), request.code(), servletRequest.getRemoteAddr());
	}

	@PostMapping("/password/forgot")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void solicitarRecuperacionContrasena(
			@Valid @RequestBody VerifyRegistrationRequest request,
			HttpServletRequest servletRequest) {
		authService.requestPasswordReset(request.identifier(), request.email(), servletRequest.getRemoteAddr());
	}

	@PostMapping("/password/forgot/verify")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void verificarCodigoRecuperacion(
			@Valid @RequestBody VerifyRegistrationCodeRequest request,
			HttpServletRequest servletRequest) {
		authService.verifyPasswordResetCode(request.identifier(), request.code(), servletRequest.getRemoteAddr());
	}

	@PostMapping("/password/reset")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	public void restablecerContrasena(
			@Valid @RequestBody ResetPasswordRequest request,
			HttpServletRequest servletRequest) {
		authService.resetPassword(request.identifier(), request.password(), servletRequest.getRemoteAddr());
	}

	@PostMapping("/login")
	public AuthResponse iniciarSesion(
			@Valid @RequestBody LoginRequest request,
			HttpServletRequest servletRequest) {
		return authService.login(request.identifier(), request.password(), servletRequest.getRemoteAddr(), request.rememberMe());
	}
}
