package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.dto.AuthResponse;

public interface AuthService {

	AuthResponse register(String identifier, String password, String clientIp);

	void verifyRegistration(String identifier, String email, String clientIp);

	void verifyRegistrationCode(String identifier, String code, String clientIp);

	void requestPasswordReset(String identifier, String email, String clientIp);

	void verifyPasswordResetCode(String identifier, String code, String clientIp);

	void resetPassword(String identifier, String password, String clientIp);

	AuthResponse login(String identifier, String password, String clientIp);

	AuthResponse login(String identifier, String password, String clientIp, boolean rememberMe);
}
