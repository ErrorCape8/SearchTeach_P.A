package com.pa.searchteach.calidad.repository;

import java.util.List;
import java.util.Optional;

import com.pa.searchteach.calidad.model.CalificacionTutoria;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface CalificacionTutoriaRepositorio extends MongoRepository<CalificacionTutoria, String> {

	Optional<CalificacionTutoria> findBySesionIdAndEstudianteId(String sesionId, String estudianteId);

	List<CalificacionTutoria> findAllByOrderByFechaCreacionDesc();
}
