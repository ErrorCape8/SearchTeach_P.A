package com.pa.searchteach.tutorias.service.grupal;

import java.time.LocalDateTime;
import java.util.List;

import com.pa.searchteach.tutorias.model.CatalogoMateriasTecnologia;
import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.users.model.User;
import com.pa.searchteach.users.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import static com.pa.searchteach.tutorias.service.grupal.ReglasTutorias.CUPO_MAXIMO_SESION_GRUPAL;
import static com.pa.searchteach.tutorias.service.grupal.ReglasTutorias.semestreValido;
import static com.pa.searchteach.tutorias.service.grupal.RelojTutorias.ahora;

/** Consultas de sesiones grupales para estudiantes, docentes y coordinación. */
@Service
public class SesionesGrupalesConsultaService {

	private final SesionTutoriaRepositorio sesiones;
	private final UserRepository usuarios;
	private final CierreSesionesService cierre;

	public SesionesGrupalesConsultaService(
			SesionTutoriaRepositorio sesiones,
			UserRepository usuarios,
			CierreSesionesService cierre) {
		this.sesiones = sesiones;
		this.usuarios = usuarios;
		this.cierre = cierre;
	}

	public List<SesionTutoria> listarDeEstudiante(String estudianteId) {
		return sesiones.findByEstudianteIdsContaining(estudianteId).stream()
				.map(cierre::cerrarSiVencida)
				.toList();
	}

	public List<SesionTutoria> listarDeDocente(String docenteId) {
		return sesiones.findByDocenteId(docenteId).stream().map(cierre::cerrarSiVencida).toList();
	}

	public List<SesionTutoria> listarDisponibles(String estudianteId) {
		User estudiante = buscarEstudiante(estudianteId);
		String tecnologia = estudiante.getCarrera() == null ? "" : estudiante.getCarrera().trim();
		if (tecnologia.isEmpty() || !semestreValido(estudiante.getSemestre())) return List.of();
		return sesiones.findAll().stream()
				.filter(sesion -> sesion.fechaFin().isAfter(ahora()))
				.filter(sesion -> !"FINALIZADA".equals(sesion.estadoClase()))
				.filter(sesion -> sesion.estudianteIds().size() < CUPO_MAXIMO_SESION_GRUPAL)
				.filter(sesion -> !sesion.estudianteIds().contains(estudianteId))
				.filter(sesion -> sesion.tecnologias().stream().anyMatch(oferta -> CatalogoMateriasTecnologia.normalizar(oferta).equals(CatalogoMateriasTecnologia.normalizar(tecnologia))))
				.filter(sesion -> sesion.semestre() == estudiante.getSemestre())
				.sorted((left, right) -> left.fechaInicio().compareTo(right.fechaInicio()))
				.toList();
	}

	public List<SesionTutoria> listarPublicadas() {
		LocalDateTime ahora = ahora();
		return sesiones.findAll().stream()
				.filter(sesion -> sesion.fechaFin().isAfter(ahora))
				.filter(sesion -> !"FINALIZADA".equals(sesion.estadoClase()))
				.sorted((left, right) -> left.fechaInicio().compareTo(right.fechaInicio()))
				.toList();
	}

	private User buscarEstudiante(String id) {
		return usuarios.findById(id)
				.orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
						"No se encontró el estudiante."));
	}
}
