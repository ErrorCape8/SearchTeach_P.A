package com.pa.searchteach.tutorias.repository;

import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.pa.searchteach.tutorias.model.MensajeProyectoAula;

public interface MensajeProyectoAulaRepositorio extends MongoRepository<MensajeProyectoAula, String> {
	List<MensajeProyectoAula> findByTutoriaColectivaIdAndProyectoIdAndSesionIdOrderByEnviadoEnAsc(
			String tutoriaColectivaId, String proyectoId, String sesionId);
	void deleteByTutoriaColectivaId(String tutoriaColectivaId);
}
