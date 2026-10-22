package com.pa.searchteach.dashboard.controller;

import com.pa.searchteach.dashboard.dto.DashboardSummary;
import com.pa.searchteach.dashboard.service.DirectorDashboardService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/direccion/dashboard")
public class DirectorDashboardController {

	private final DirectorDashboardService dashboardService;

	public DirectorDashboardController(DirectorDashboardService dashboardService) {
		this.dashboardService = dashboardService;
	}

	@GetMapping
	public DashboardSummary obtenerResumenDelDashboard() {
		return dashboardService.obtenerResumen();
	}
}
