package com.pa.searchteach.tutorias.servicio;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.tutorias.dto.InformeAvanceSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaConAvance;
import com.pa.searchteach.tutorias.dto.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.dto.ProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaConAvance;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.modelo.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.modelo.ProyectoAula;
import com.pa.searchteach.tutorias.modelo.TutoriaColectiva;
import com.pa.searchteach.tutorias.repositorio.InformeAvanceProyectoRepositorio;
import com.pa.searchteach.tutorias.repositorio.TutoriaColectivaRepositorio;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.stereotype.Service;

@Service
public class TutoriasColectivasService {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final InformeAvanceProyectoRepositorio informeRepositorio;
	private final UserRepository userRepository;

	public TutoriasColectivasService(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			InformeAvanceProyectoRepositorio informeRepositorio,
			UserRepository userRepository) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.informeRepositorio = informeRepositorio;
		this.userRepository = userRepository;
	}

	public TutoriaColectiva crear(TutoriaColectivaSolicitud solicitud, String coordinadoraId) {
		List<String> docentes = new ArrayList<>(solicitud.docentesApoyoIds());
		docentes.add(solicitud.docenteLiderId());
		if (docentes.stream().anyMatch(docenteId -> !userRepository.existsById(docenteId))) {
			throw new IllegalArgumentException(
					"El docente líder y los docentes de apoyo deben tener una cuenta registrada.");
		}
		List<ProyectoAula> proyectos = solicitud.proyectos().stream()
				.map(this::crearProyecto)
				.toList();
		TutoriaColectiva tutoriaColectiva = new TutoriaColectiva(
				null,
				coordinadoraId,
				solicitud.docenteLiderId(),
				solicitud.docentesApoyoIds(),
				proyectos,
				LocalDateTime.now());
		return tutoriaColectivaRepositorio.save(tutoriaColectiva);
	}

	public InformeAvanceProyecto registrarInforme(
			String tutoriaColectivaId,
			String proyectoId,
			InformeAvanceSolicitud solicitud,
			String docenteId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaColectivaId);
		ProyectoAula proyecto = tutoria.proyectos().stream()
				.filter(actual -> actual.proyectoId().equals(proyectoId))
				.findFirst()
				.orElseThrow(() -> new NotFoundException("No se encontró el proyecto del grupo."));
		if (!proyecto.docenteResponsableId().equals(docenteId)) {
			throw new ForbiddenException("Solo el docente de apoyo asignado puede reportar este proyecto.");
		}
		InformeAvanceProyecto informe = new InformeAvanceProyecto(
				UUID.randomUUID().toString(),
				tutoriaColectivaId,
				proyectoId,
				docenteId,
				solicitud.puntajeAvance(),
				solicitud.observaciones(),
				LocalDateTime.now());
		return informeRepositorio.save(informe);
	}

	public List<TutoriaColectivaConAvance> listarParaLiderPrograma() {
		return tutoriaColectivaRepositorio.findAll().stream()
				.map(tutoria -> new TutoriaColectivaConAvance(
						tutoria,
						tutoria.proyectos().stream()
								.map(proyecto -> {
									List<InformeAvanceProyecto> informes = informeRepositorio
											.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInformeAsc(
													tutoria.id(),
													proyecto.proyectoId());
									return new ProyectoAulaConAvance(
											proyecto,
											informes,
											ModeloMejoraProyecto.evaluar(informes));
								})
								.toList()))
				.toList();
	}

	public List<ProyectoAsignadoDocente> listarProyectosDeDocente(String docenteId) {
		return tutoriaColectivaRepositorio.findAll().stream()
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.filter(proyecto -> proyecto.docenteResponsableId().equals(docenteId))
						.map(proyecto -> new ProyectoAsignadoDocente(tutoria.id(), proyecto)))
				.toList();
	}

	private TutoriaColectiva buscarTutoria(String id) {
		return tutoriaColectivaRepositorio.findById(id)
				.orElseThrow(() -> new NotFoundException("No se encontró la tutoría colectiva."));
	}

	private ProyectoAula crearProyecto(ProyectoAulaSolicitud solicitud) {
		return new ProyectoAula(
				UUID.randomUUID().toString(),
				solicitud.nombre(),
				solicitud.docenteResponsableId(),
				solicitud.estudianteIds(),
				solicitud.tecnologia(),
				solicitud.semestre());
	}
}
