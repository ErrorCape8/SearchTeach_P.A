package com.pa.searchteach.tutorias.repository;

import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.pa.searchteach.tutorias.model.SesionProyectoAula;

public interface SesionProyectoAulaRepositorio extends MongoRepository<SesionProyectoAula, String> {
	List<SesionProyectoAula> findByTutoriaColectivaIdAndProyectoIdOrderByFechaInicioDesc(
			String tutoriaColectivaId, String proyectoId);
	void deleteByTutoriaColectivaId(String tutoriaColectivaId);
	java.util.Optional<SesionProyectoAula> findByIdAndTutoriaColectivaIdAndProyectoId(
			String id, String tutoriaColectivaId, String proyectoId);
}
