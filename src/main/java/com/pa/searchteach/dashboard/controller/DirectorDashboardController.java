package com.pa.searchteach.dashboard.controller;

import com.pa.searchteach.dashboard.dto.DashboardSummary;
import com.pa.searchteach.dashboard.dto.PaGruposResumen;
import com.pa.searchteach.dashboard.service.PaGruposDashboardService;
import com.pa.searchteach.dashboard.service.DirectorDashboardService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/direccion/dashboard")
public class DirectorDashboardController {

	private final DirectorDashboardService dashboardService;
	private final PaGruposDashboardService paGruposService;

	public DirectorDashboardController(
			DirectorDashboardService dashboardService,
			PaGruposDashboardService paGruposService) {
		this.dashboardService = dashboardService;
		this.paGruposService = paGruposService;
	}

	@GetMapping
	public DashboardSummary obtenerResumenDelDashboard() {
		return dashboardService.obtenerResumen();
	}

	@GetMapping("/pa-grupos")
	public PaGruposResumen obtenerPronosticoGruposPa() {
		return paGruposService.obtenerResumen();
	}
}
