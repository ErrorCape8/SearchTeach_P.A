package com.pa.searchteach.tutorias.repository;

import org.springframework.data.mongodb.repository.MongoRepository;

import com.pa.searchteach.tutorias.model.TutoriaColectiva;

public interface TutoriaColectivaRepositorio extends MongoRepository<TutoriaColectiva, String> {
}
