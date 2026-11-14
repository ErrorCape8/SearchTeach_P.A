package com.pa.searchteach.tutorias.service.colectivas;

import java.util.List;

import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAsignadoDocente;
import com.pa.searchteach.tutorias.dto.colectivas.ProyectoAulaSeguimientoEstudiante;
import com.pa.searchteach.tutorias.dto.colectivas.TutoriaColectivaLider;
import com.pa.searchteach.tutorias.repository.InformeAvanceProyectoRepositorio;
import com.pa.searchteach.tutorias.repository.SesionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.stereotype.Service;

/** Listados de proyectos de aula para estudiantes, docentes y docente líder. */
@Service
public class ConsultaProyectosAulaService {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final UserRepository userRepository;
	private final SesionProyectoAulaRepositorio sesionProyectoRepositorio;
	private final InformeAvanceProyectoRepositorio informeRepositorio;

	public ConsultaProyectosAulaService(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			UserRepository userRepository,
			SesionProyectoAulaRepositorio sesionProyectoRepositorio,
			InformeAvanceProyectoRepositorio informeRepositorio) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.userRepository = userRepository;
		this.sesionProyectoRepositorio = sesionProyectoRepositorio;
		this.informeRepositorio = informeRepositorio;
	}

	public List<ProyectoAulaSeguimientoEstudiante> listarSeguimientoEstudiante(String estudianteId) {
		return tutoriaColectivaRepositorio.findAll().stream()
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.filter(proyecto -> proyecto.estudianteIds().contains(estudianteId))
						.map(proyecto -> new ProyectoAulaSeguimientoEstudiante(
								tutoria.id(), tutoria.estado(), proyecto, proyecto.codigoInscripcion(),
								userRepository.findById(proyecto.docenteResponsableId()).map(User::getNombre)
										.orElse(proyecto.docenteResponsableId()),
								sesionProyectoRepositorio.findByTutoriaColectivaIdAndProyectoIdOrderByFechaInicioDesc(
										tutoria.id(), proyecto.proyectoId()))))
				.toList();
	}

	public List<ProyectoAsignadoDocente> listarProyectosParaLider(String docenteLiderId) {
		return tutoriaColectivaRepositorio.findAll().stream()
				.filter(tutoria -> "ACTIVA".equals(tutoria.estado()))
				.filter(tutoria -> tutoria.docenteLiderId().equals(docenteLiderId))
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.map(proyecto -> new ProyectoAsignadoDocente(tutoria.id(), proyecto)))
				.toList();
	}

	public List<TutoriaColectivaLider> listarTutoriasParaLider(String docenteLiderId) {
		return tutoriaColectivaRepositorio.findAll().stream()
				.filter(tutoria -> tutoria.docenteLiderId().equals(docenteLiderId))
				// Un grupo con todos los proyectos finalizados se disuelve solo, pero el líder
				// todavía debe poder enviar (o consultar) el informe general.
				.filter(tutoria -> "ACTIVA".equals(tutoria.estado()) || todosFinalizados(tutoria))
				.map(tutoria -> new TutoriaColectivaLider(
						tutoria.id(),
						tutoria.tecnologia(),
						tutoria.semestre(),
						tutoria.docentesApoyoIds().stream()
								.map(id -> new TutoriaColectivaLider.DocenteAsignado(
										id,
										userRepository.findById(id)
												.map(User::getNombre)
												.filter(nombre -> nombre != null && !nombre.isBlank())
												.orElse(id)))
								.toList(),
						tutoria.proyectos(),
						tutoria.estado(),
						informeRepositorio.existsByTutoriaColectivaId(tutoria.id())))
				.toList();
	}

	private boolean todosFinalizados(com.pa.searchteach.tutorias.model.TutoriaColectiva tutoria) {
		return !tutoria.proyectos().isEmpty() && tutoria.proyectos().stream()
				.allMatch(proyecto -> "FINALIZADO".equals(proyecto.estadoCierre()));
	}

	public List<ProyectoAsignadoDocente> listarProyectosDeDocente(String docenteId) {
		return tutoriaColectivaRepositorio.findAll().stream()
				.filter(tutoria -> "ACTIVA".equals(tutoria.estado()))
				.flatMap(tutoria -> tutoria.proyectos().stream()
						.filter(proyecto -> proyecto.docenteResponsableId().equals(docenteId))
						.map(proyecto -> new ProyectoAsignadoDocente(tutoria.id(), proyecto)))
				.toList();
	}
}
