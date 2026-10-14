package com.pa.searchteach.it.repository;

import com.pa.searchteach.it.model.ItAdmin;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ItAdminRepository extends MongoRepository<ItAdmin, String> {
}
