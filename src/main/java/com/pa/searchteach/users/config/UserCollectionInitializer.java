package com.pa.searchteach.users.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.stereotype.Component;
import java.time.Duration;

@Component
public class UserCollectionInitializer implements ApplicationRunner {

	private static final String USERS_COLLECTION = "users";
	private static final String PROGRAM_LEADERS_COLLECTION = "program_leaders";
	private static final String COORDINATORS_COLLECTION = "coordinators";
	private static final String GROUP_TUTORING_COLLECTION = "sesiones_tutoria";
	private static final String COLLECTIVE_TUTORING_COLLECTION = "tutorias_colectivas";
	private static final String PROJECT_REPORTS_COLLECTION = "informes_avance_proyecto";
	private static final String PROJECT_SESSIONS_COLLECTION = "sesiones_proyecto_aula";
	private static final String PROJECT_MESSAGES_COLLECTION = "mensajes_proyecto_aula";
	private static final String IT_COLLECTION = "it";
	private static final String PROFILE_CHANGE_COLLECTION = "cambios_perfil_pendientes";

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
		if (!mongoTemplate.collectionExists(PROJECT_SESSIONS_COLLECTION)) {
			mongoTemplate.createCollection(PROJECT_SESSIONS_COLLECTION);
		}
		if (!mongoTemplate.collectionExists(PROJECT_MESSAGES_COLLECTION)) {
			mongoTemplate.createCollection(PROJECT_MESSAGES_COLLECTION);
		}
		if (!mongoTemplate.collectionExists(PROFILE_CHANGE_COLLECTION)) {
			mongoTemplate.createCollection(PROFILE_CHANGE_COLLECTION);
		}
		mongoTemplate.indexOps(PROFILE_CHANGE_COLLECTION).ensureIndex(
				new Index().on("expiraEn", Sort.Direction.ASC).expire(Duration.ZERO));
	}
}
