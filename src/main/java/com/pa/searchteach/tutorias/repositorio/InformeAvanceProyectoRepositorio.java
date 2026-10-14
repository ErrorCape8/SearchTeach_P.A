package com.pa.searchteach.tutorias.repositorio;

import java.util.List;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.pa.searchteach.tutorias.modelo.InformeAvanceProyecto;

public interface InformeAvanceProyectoRepositorio extends MongoRepository<InformeAvanceProyecto, String> {

	List<InformeAvanceProyecto> findByTutoriaColectivaIdAndProyectoIdOrderByFechaInformeAsc(
			String tutoriaColectivaId,
			String proyectoId);
}
