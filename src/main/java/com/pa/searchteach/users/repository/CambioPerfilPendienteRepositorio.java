package com.pa.searchteach.users.repository;

import com.pa.searchteach.users.model.CambioPerfilPendiente;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface CambioPerfilPendienteRepositorio extends MongoRepository<CambioPerfilPendiente, String> {
}
