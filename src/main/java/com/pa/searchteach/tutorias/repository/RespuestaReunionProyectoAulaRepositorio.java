package com.pa.searchteach.tutorias.repository;

import java.util.Optional;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.pa.searchteach.tutorias.model.RespuestaReunionProyectoAula;

public interface RespuestaReunionProyectoAulaRepositorio
		extends MongoRepository<RespuestaReunionProyectoAula, String> {
	Optional<RespuestaReunionProyectoAula> findTopByTutoriaColectivaIdAndProyectoIdAndSesionIdOrderByActualizadaEnDesc(
			String tutoriaColectivaId, String proyectoId, String sesionId);
	void deleteByTutoriaColectivaId(String tutoriaColectivaId);
}
