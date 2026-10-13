package com.pa.searchteach.coordinators.repository;

import com.pa.searchteach.coordinators.model.Coordinator;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface CoordinatorRepository extends MongoRepository<Coordinator, String> {
}
