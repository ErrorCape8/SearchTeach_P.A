package com.pa.searchteach.users.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Component;

@Component
public class UserCollectionInitializer implements ApplicationRunner {

	private static final String USERS_COLLECTION = "users";
	private static final String PROGRAM_LEADERS_COLLECTION = "program_leaders";
	private static final String COORDINATORS_COLLECTION = "coordinators";
	private static final String GROUP_TUTORING_COLLECTION = "sesiones_tutoria";
	private static final String COLLECTIVE_TUTORING_COLLECTION = "tutorias_colectivas";
	private static final String PROJECT_REPORTS_COLLECTION = "informes_avance_proyecto";
	private static final String IT_COLLECTION = "it";

	private final MongoTemplate mongoTemplate;

	public UserCollectionInitializer(MongoTemplate mongoTemplate) {
		this.mongoTemplate = mongoTemplate;
	}

	@Override
	public void run(ApplicationArguments args) {
		if (!mongoTemplate.collectionExists(USERS_COLLECTION)) {
			mongoTemplate.createCollection(USERS_COLLECTION);
		}
		if (!mongoTemplate.collectionExists(IT_COLLECTION)) {
			mongoTemplate.createCollection(IT_COLLECTION);
		}
		if (!mongoTemplate.collectionExists(PROGRAM_LEADERS_COLLECTION)) {
			mongoTemplate.createCollection(PROGRAM_LEADERS_COLLECTION);
		}
		if (!mongoTemplate.collectionExists(COORDINATORS_COLLECTION)) {
			mongoTemplate.createCollection(COORDINATORS_COLLECTION);
		}
		if (!mongoTemplate.collectionExists(GROUP_TUTORING_COLLECTION)) {
			mongoTemplate.createCollection(GROUP_TUTORING_COLLECTION);
		}
		if (!mongoTemplate.collectionExists(COLLECTIVE_TUTORING_COLLECTION)) {
			mongoTemplate.createCollection(COLLECTIVE_TUTORING_COLLECTION);
		}
		if (!mongoTemplate.collectionExists(PROJECT_REPORTS_COLLECTION)) {
			mongoTemplate.createCollection(PROJECT_REPORTS_COLLECTION);
		}
	}
}
