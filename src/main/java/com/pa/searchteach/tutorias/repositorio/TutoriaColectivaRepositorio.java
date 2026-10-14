package com.pa.searchteach.tutorias.repositorio;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.pa.searchteach.tutorias.modelo.TutoriaColectiva;

public interface TutoriaColectivaRepositorio extends MongoRepository<TutoriaColectiva, String> {
}
