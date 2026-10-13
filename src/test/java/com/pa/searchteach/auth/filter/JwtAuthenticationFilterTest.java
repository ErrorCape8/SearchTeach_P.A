package com.pa.searchteach.auth.filter;

import com.pa.searchteach.auth.service.JwtService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockFilterChain;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.assertj.core.api.Assertions.assertThat;

class JwtAuthenticationFilterTest {

	private static final String JWT_SECRET = "0123456789abcdef0123456789abcdef";

	@AfterEach
	void clearSecurityContext() {
		SecurityContextHolder.clearContext();
	}

	@Test
	void grantsDirectorAuthorityToConfiguredIdentifier() throws Exception {
		assertAuthorityFor("00123456", " 00987654, 00123456 ", "ROLE_DIRECTOR");
	}

	@Test
	void doesNotGrantDirectorAuthorityToUnconfiguredIdentifier() throws Exception {
		assertAuthorityFor("00123456", "00987654", "ROLE_USER");
	}

	private void assertAuthorityFor(
			String identifier, String configuredDirectorIds, String expectedAuthority)
			throws Exception {
		JwtService jwtService = new JwtService(JWT_SECRET, 900);
		JwtAuthenticationFilter filter =
				new JwtAuthenticationFilter(jwtService, configuredDirectorIds);
		MockHttpServletRequest request = new MockHttpServletRequest();
		request.setServletPath("/api/direccion/dashboard");
		request.addHeader("Authorization", "Bearer " + jwtService.createToken(identifier));

		filter.doFilter(
				request,
				new MockHttpServletResponse(),
				new MockFilterChain());

		var authentication = SecurityContextHolder.getContext().getAuthentication();
		assertThat(authentication).isNotNull();
		assertThat(authentication.getAuthorities())
				.extracting("authority")
				.contains("ROLE_USER");
		assertThat(authentication.getAuthorities())
				.extracting("authority")
				.contains(expectedAuthority);
		if ("ROLE_USER".equals(expectedAuthority)) {
			assertThat(authentication.getAuthorities())
					.extracting("authority")
					.doesNotContain("ROLE_DIRECTOR");
		}
	}
}
