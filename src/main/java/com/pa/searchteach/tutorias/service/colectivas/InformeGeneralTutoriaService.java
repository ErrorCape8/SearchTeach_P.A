package com.pa.searchteach.tutorias.service.colectivas;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.InformeAvanceProyectoRepositorio;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/** Informe general del docente líder para coordinación, una vez aceptados todos los reportes de apoyo. */
@Service
public class InformeGeneralTutoriaService {

	private final InformeAvanceProyectoRepositorio informeRepositorio;
	private final NotificationService notificationService;
	private final BusquedaProyectosAula busqueda;

	public InformeGeneralTutoriaService(
			InformeAvanceProyectoRepositorio informeRepositorio,
			NotificationService notificationService,
			BusquedaProyectosAula busqueda) {
		this.informeRepositorio = informeRepositorio;
		this.notificationService = notificationService;
		this.busqueda = busqueda;
	}

	public InformeAvanceProyecto enviar(String tutoriaId, String contenido, String docenteLiderId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		validarLider(tutoria, docenteLiderId);
		if (contenido == null || contenido.isBlank() || contenido.length() > 12000) {
			throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
					"El informe general es obligatorio y admite hasta 12000 caracteres.");
		}
		boolean todosFinalizados = !tutoria.proyectos().isEmpty()
				&& tutoria.proyectos().stream().allMatch(proyecto -> "FINALIZADO".equals(proyecto.estadoCierre()));
		if (!todosFinalizados) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El informe general se envía cuando todos los reportes de los docentes de apoyo estén aceptados.");
		}
		if (informeRepositorio.existsByTutoriaColectivaId(tutoriaId)) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"El informe general de este grupo ya fue enviado.");
		}
		InformeAvanceProyecto informe = informeRepositorio.save(new InformeAvanceProyecto(
				null, tutoriaId, docenteLiderId, contenido.trim(), LocalDateTime.now()));
		notificationService.notifyUser(tutoria.coordinadoraId(), "Informe general del grupo de proyecto",
				"El docente líder envió el informe general del grupo de " + tutoria.tecnologia() + ".",
				"/notificaciones");
		return informe;
	}

	public InformeAvanceProyecto consultarComoLider(String tutoriaId, String docenteLiderId) {
		TutoriaColectiva tutoria = busqueda.buscarTutoria(tutoriaId);
		validarLider(tutoria, docenteLiderId);
		return buscarInforme(tutoriaId);
	}

	public InformeAvanceProyecto consultarComoCoordinacion(String tutoriaId) {
		busqueda.buscarTutoria(tutoriaId);
		return buscarInforme(tutoriaId);
	}

	public List<InformeAvanceProyecto> listarParaCoordinacion() {
		return informeRepositorio.findAll();
	}

	private void validarLider(TutoriaColectiva tutoria, String docenteLiderId) {
		if (!tutoria.docenteLiderId().equals(docenteLiderId)) {
			throw new ForbiddenException("Solo el docente líder puede gestionar el informe general.");
		}
	}

	private InformeAvanceProyecto buscarInforme(String tutoriaId) {
		return informeRepositorio.findFirstByTutoriaColectivaId(tutoriaId)
				.orElseThrow(() -> new NotFoundException("El docente líder aún no ha enviado el informe general."));
	}
}
