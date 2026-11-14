package com.pa.searchteach.tutorias.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;

public interface InformeAvanceProyectoRepositorio extends MongoRepository<InformeAvanceProyecto, String> {

	List<InformeAvanceProyecto> findByTutoriaColectivaId(String tutoriaColectivaId);

	Optional<InformeAvanceProyecto> findFirstByTutoriaColectivaId(String tutoriaColectivaId);

	boolean existsByTutoriaColectivaId(String tutoriaColectivaId);
}
