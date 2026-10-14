package com.pa.searchteach.tutorias.repositorio;

import java.util.List;

import com.pa.searchteach.tutorias.modelo.SesionTutoria;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface SesionTutoriaRepositorio extends MongoRepository<SesionTutoria, String> {

	List<SesionTutoria> findByDocenteId(String docenteId);

	List<SesionTutoria> findByEstudianteIdsContaining(String estudianteId);

	List<SesionTutoria> findByDocenteIdAndFechaInicioAndMateriaIgnoreCase(
			String docenteId, java.time.LocalDateTime fechaInicio, String materia);
}
