package com.pa.searchteach.tutorias.repository;

import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.pa.searchteach.tutorias.model.InformeAvanceProyecto;

public interface InformeAvanceProyectoRepositorio extends MongoRepository<InformeAvanceProyecto, String> {

	List<InformeAvanceProyecto> findByTutoriaColectivaIdAndProyectoIdOrderByFechaInformeAsc(
			String tutoriaColectivaId,
			String proyectoId);

	List<InformeAvanceProyecto> findByTutoriaColectivaId(String tutoriaColectivaId);
}
