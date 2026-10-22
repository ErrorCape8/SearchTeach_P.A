package com.pa.searchteach.tutorias.repository;

import java.util.List;
import java.util.Optional;

import com.pa.searchteach.tutorias.model.HorarioTutor;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface HorarioTutorRepository extends MongoRepository<HorarioTutor, String> {
	List<HorarioTutor> findAllByOrderByActualizadoEnDesc();

	Optional<HorarioTutor> findByDocenteId(String docenteId);

	void deleteByDocenteId(String docenteId);
}
