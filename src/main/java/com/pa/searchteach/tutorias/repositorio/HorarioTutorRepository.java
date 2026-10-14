package com.pa.searchteach.tutorias.repositorio;

import java.util.List;
import java.util.Optional;

import com.pa.searchteach.tutorias.modelo.HorarioTutor;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface HorarioTutorRepository extends MongoRepository<HorarioTutor, String> {
	List<HorarioTutor> findAllByOrderByActualizadoEnDesc();

	Optional<HorarioTutor> findByDocenteId(String docenteId);
}
