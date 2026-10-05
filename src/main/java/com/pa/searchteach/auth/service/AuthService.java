package com.pa.searchteach.auth.service;

import com.pa.searchteach.auth.dto.AuthResponse;

public interface AuthService {

	AuthResponse register(String identifier, String password, String clientIp);

	AuthResponse login(String identifier, String password, String clientIp);
}
