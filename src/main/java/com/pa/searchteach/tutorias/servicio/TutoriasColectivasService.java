package com.pa.searchteach.tutorias.servicio;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import com.pa.searchteach.common.exception.ForbiddenException;
import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.tutorias.dto.InformeAvanceSolicitud;
import com.pa.searchteach.tutorias.dto.ProyectoAulaConAvance;
import com.pa.searchteach.tutorias.dto.ProyectoAulaDisponible;
import com.pa.searchteach.tutorias.dto.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.dto.ProyectoAulaSolicitud;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaConAvance;
import com.pa.searchteach.tutorias.dto.TutoriaColectivaSolicitud;
import com.pa.searchteach.tutorias.modelo.InformeAvanceProyecto;
import com.pa.searchteach.tutorias.modelo.ProyectoAula;
import com.pa.searchteach.tutorias.modelo.CatalogoTecnologias;
import com.pa.searchteach.tutorias.modelo.TutoriaColectiva;
import com.pa.searchteach.tutorias.repositorio.InformeAvanceProyectoRepositorio;
import com.pa.searchteach.tutorias.repositorio.TutoriaColectivaRepositorio;
import com.pa.searchteach.users.repository.UserRepository;
import com.pa.searchteach.users.model.User;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

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

	public List<TutoriaColectiva> listarParaCoordinacion() {
		return tutoriaColectivaRepositorio.findAll();
	}

	public List<ProyectoAulaDisponible> listarEspaciosParaEstudiante(String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		return tutoriaColectivaRepositorio.findAll().stream()
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.filter(proyecto -> proyecto.tecnologia().equalsIgnoreCase(estudiante.getCarrera() == null ? "" : estudiante.getCarrera()))
						.map(proyecto -> disponible(tutoria.id(), proyecto, estudianteId)))
				.toList();
	}

	public ProyectoAulaDisponible inscribirEstudiante(String tutoriaId, String proyectoId, String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		validarTecnologia(estudiante, proyecto);
		boolean inscritoEnOtroSemestre = tutoria.proyectos().stream()
				.anyMatch(otro -> !otro.proyectoId().equals(proyectoId)
						&& otro.estudianteIds().contains(estudianteId));
		if (inscritoEnOtroSemestre) {
			throw new ResponseStatusException(HttpStatus.CONFLICT,
					"Ya estás inscrito en otro semestre de este proyecto de aula.");
		}
		if (proyecto.estudianteIds().size() >= 4 && !proyecto.estudianteIds().contains(estudianteId)) {
			throw new ResponseStatusException(HttpStatus.CONFLICT, "Este espacio ya tiene cuatro estudiantes inscritos.");
		}
		ProyectoAula actualizado = proyecto.inscribir(estudianteId);
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		return disponible(tutoriaId, actualizado, estudianteId);
	}

	public ProyectoAulaDisponible desistirEstudiante(String tutoriaId, String proyectoId, String estudianteId) {
		TutoriaColectiva tutoria = buscarTutoria(tutoriaId);
		ProyectoAula proyecto = buscarProyecto(tutoria, proyectoId);
		ProyectoAula actualizado = proyecto.desistir(estudianteId);
		tutoriaColectivaRepositorio.save(tutoria.actualizarProyecto(actualizado));
		return disponible(tutoriaId, actualizado, estudianteId);
	}

	public List<InformeAvanceProyecto> listarInformesParaCoordinacion() {
		return informeRepositorio.findAll().stream()
				.sorted((a, b) -> b.fechaInforme().compareTo(a.fechaInforme()))
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

	private ProyectoAula buscarProyecto(TutoriaColectiva tutoria, String proyectoId) {
		return tutoria.proyectos().stream()
				.filter(proyecto -> proyecto.proyectoId().equals(proyectoId))
				.findFirst()
				.orElseThrow(() -> new NotFoundException("No se encontró el espacio de proyecto."));
	}

	private User buscarEstudiante(String id) {
		return userRepository.findById(id)
				.orElseThrow(() -> new NotFoundException("No se encontró el usuario estudiante."));
	}

	private void validarTecnologia(User estudiante, ProyectoAula proyecto) {
		if (estudiante.getCarrera() == null || estudiante.getCarrera().isBlank()
				|| !estudiante.getCarrera().equalsIgnoreCase(proyecto.tecnologia())) {
			throw new ResponseStatusException(HttpStatus.FORBIDDEN,
					"Solo pueden inscribirse estudiantes de la tecnología del espacio.");
		}
	}

	private ProyectoAulaDisponible disponible(String tutoriaId, ProyectoAula proyecto, String estudianteId) {
		return new ProyectoAulaDisponible(tutoriaId, proyecto.proyectoId(), proyecto.nombre(),
				proyecto.docenteResponsableId(), proyecto.tecnologia(), proyecto.semestre(),
				proyecto.estudianteIds().size(), proyecto.estudianteIds().contains(estudianteId));
	}

	private ProyectoAula crearProyecto(ProyectoAulaSolicitud solicitud) {
		if (!CatalogoTecnologias.contiene(solicitud.tecnologia())) {
			throw new IllegalArgumentException("Selecciona una tecnología del catálogo institucional.");
		}
		return new ProyectoAula(
				UUID.randomUUID().toString(),
				solicitud.nombre(),
				solicitud.docenteResponsableId(),
				List.of(),
				solicitud.tecnologia(),
				solicitud.semestre());
	}
}
