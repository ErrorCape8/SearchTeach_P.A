package com.pa.searchteach.programleaders.repository;

import com.pa.searchteach.programleaders.model.LiderPrograma;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface RepositorioLiderPrograma extends MongoRepository<LiderPrograma, String> {
}
