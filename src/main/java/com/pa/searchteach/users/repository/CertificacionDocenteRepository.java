package com.pa.searchteach.users.repository;

import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;
import com.pa.searchteach.users.model.CertificacionDocente;

public interface CertificacionDocenteRepository extends MongoRepository<CertificacionDocente, String> {
	List<CertificacionDocente> findByDocenteIdOrderByCreadaEnDesc(String docenteId);
	List<CertificacionDocente> findAllByOrderByCreadaEnDesc();
}
