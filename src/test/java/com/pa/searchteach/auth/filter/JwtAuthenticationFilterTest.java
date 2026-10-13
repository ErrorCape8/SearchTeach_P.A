package com.pa.searchteach.auth.filter;

import com.pa.searchteach.auth.service.JwtService;
import com.pa.searchteach.users.model.Role;
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
	void grantsDirectorAuthorityFromSignedTokenRole() throws Exception {
		assertAuthorityFor("00123456", Role.DIRECTOR, "ROLE_DIRECTOR");
	}

	@Test
	void doesNotGrantDirectorAuthorityToUserToken() throws Exception {
		assertAuthorityFor("00123456", Role.USER, "ROLE_USER");
	}

	private void assertAuthorityFor(
			String identifier, Role role, String expectedAuthority)
			throws Exception {
		JwtService jwtService = new JwtService(JWT_SECRET, 900);
		JwtAuthenticationFilter filter = new JwtAuthenticationFilter(jwtService);
		MockHttpServletRequest request = new MockHttpServletRequest();
		request.setServletPath("/api/direccion/dashboard");
		request.addHeader("Authorization", "Bearer " + jwtService.createToken(identifier, role));

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
