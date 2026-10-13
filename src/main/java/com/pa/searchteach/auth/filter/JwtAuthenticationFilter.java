package com.pa.searchteach.auth.filter;

import com.pa.searchteach.auth.service.JwtService;
import com.pa.searchteach.users.model.Role;
import io.jsonwebtoken.JwtException;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

public class JwtAuthenticationFilter extends OncePerRequestFilter {

	private final JwtService jwtService;
	private final Set<String> directorIds;

	public JwtAuthenticationFilter(JwtService jwtService, String directorIds) {
		this.jwtService = jwtService;
		this.directorIds = Arrays.stream(directorIds.split(","))
				.map(identifier -> identifier == null ? "" : identifier.trim())
				.filter(identifier -> !identifier.isEmpty())
				.collect(Collectors.toUnmodifiableSet());
	}

	@Override
	protected boolean shouldNotFilter(HttpServletRequest request) {
		return request.getServletPath().startsWith("/api/auth/");
	}

	@Override
	protected void doFilterInternal(
			HttpServletRequest request,
			HttpServletResponse response,
			FilterChain filterChain) throws ServletException, IOException {
		String authorization = request.getHeader("Authorization");
		if (authorization == null || !authorization.startsWith("Bearer ")) {
			filterChain.doFilter(request, response);
			return;
		}

		String identifier;
		try {
			identifier = jwtService.getSubject(authorization.substring(7));
		} catch (JwtException | IllegalArgumentException exception) {
			SecurityContextHolder.clearContext();
			response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
			response.setContentType(MediaType.APPLICATION_JSON_VALUE);
			response.setCharacterEncoding("UTF-8");
			response.getWriter().write(
					"{\"message\":\"El token es inválido o ha vencido.\","
							+ "\"retryable\":false,\"retryAfterSeconds\":0}");
			return;
		}

		List<SimpleGrantedAuthority> authorities = new ArrayList<>();
		authorities.add(new SimpleGrantedAuthority("ROLE_USER"));
		if (directorIds.contains(identifier)) {
			authorities.add(new SimpleGrantedAuthority("ROLE_" + Role.DIRECTOR.name()));
		}
		UsernamePasswordAuthenticationToken authentication =
				new UsernamePasswordAuthenticationToken(identifier, null, authorities);
		authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
		SecurityContextHolder.getContext().setAuthentication(authentication);
		filterChain.doFilter(request, response);
	}
}
