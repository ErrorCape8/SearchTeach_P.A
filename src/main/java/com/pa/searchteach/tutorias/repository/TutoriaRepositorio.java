package com.pa.searchteach.tutorias.repository;

import java.util.List;

import com.pa.searchteach.tutorias.model.Tutoria;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface TutoriaRepositorio extends MongoRepository<Tutoria, String> {

	List<Tutoria> findByEstudianteIdOrDocenteId(String estudianteId, String docenteId);

	List<Tutoria> findByEstudianteId(String estudianteId);
}
