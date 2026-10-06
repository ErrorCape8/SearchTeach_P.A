package com.pa.searchteach.users.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Component;

@Component
public class UserCollectionInitializer implements ApplicationRunner {

	private static final String USERS_COLLECTION = "users";

	private final MongoTemplate mongoTemplate;

	public UserCollectionInitializer(MongoTemplate mongoTemplate) {
		this.mongoTemplate = mongoTemplate;
	}

	@Override
	public void run(ApplicationArguments args) {
		if (!mongoTemplate.collectionExists(USERS_COLLECTION)) {
			mongoTemplate.createCollection(USERS_COLLECTION);
		}
	}
}
