package com.pa.searchteach.tutorias.repository;

import java.util.List;
import org.springframework.data.mongodb.repository.MongoRepository;
import com.pa.searchteach.tutorias.model.SolicitudCambioFechaSesion;

public interface SolicitudCambioFechaSesionRepositorio
		extends MongoRepository<SolicitudCambioFechaSesion, String> {
	List<SolicitudCambioFechaSesion> findByEstadoOrderByCreadaEnAsc(String estado);
	boolean existsBySesionIdAndEstado(String sesionId, String estado);
}
