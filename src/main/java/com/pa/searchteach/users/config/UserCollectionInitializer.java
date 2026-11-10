package com.pa.searchteach.users.config;

import com.mongodb.MongoNamespace;
import com.mongodb.client.MongoCollection;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.bson.Document;
import com.mongodb.client.model.Filters;
import com.mongodb.client.model.ReplaceOptions;
import org.springframework.stereotype.Component;

@Component
public class UserCollectionInitializer implements ApplicationRunner {

	private static final String USERS_COLLECTION = "users";
	private static final String PROGRAM_LEADERS_COLLECTION = "program_leaders";
	private static final String COORDINATORS_COLLECTION = "coordinators";
	private static final String RETRO_TUTORING_COLLECTION = "tutorias_retroalimentativas";
	private static final String GROUP_TUTORING_COLLECTION = "sesiones_retroalimentativas";
	private static final String COLLECTIVE_TUTORING_COLLECTION = "grupos_proyectos_aula";
	private static final String PROJECT_REPORTS_COLLECTION = "informes_avance_proyecto";
	private static final String PROJECT_SESSIONS_COLLECTION = "seguimiento_proyectos_aula";
	private static final String PROJECT_MESSAGES_COLLECTION = "mensajes_proyecto_aula";
	private static final String IT_COLLECTION = "it";

	private final MongoTemplate mongoTemplate;

	public UserCollectionInitializer(MongoTemplate mongoTemplate) {
		this.mongoTemplate = mongoTemplate;
	}

	@Override
	public void run(ApplicationArguments args) {
		migrarColeccion("tutorias", "tutorias_retroalimentativas");
		migrarColeccion("sesiones_tutoria", GROUP_TUTORING_COLLECTION);
		migrarColeccion("tutorias_colectivas", COLLECTIVE_TUTORING_COLLECTION);
		migrarColeccion("sesiones_proyecto_aula", PROJECT_SESSIONS_COLLECTION);
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
		if (!mongoTemplate.collectionExists(RETRO_TUTORING_COLLECTION)) {
			mongoTemplate.createCollection(RETRO_TUTORING_COLLECTION);
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
	}

	private void migrarColeccion(String origen, String destino) {
		if (!mongoTemplate.collectionExists(origen)) {
			return;
		}
		if (!mongoTemplate.collectionExists(destino)) {
			mongoTemplate.getDb().getCollection(origen)
					.renameCollection(new MongoNamespace(mongoTemplate.getDb().getName(), destino));
			return;
		}

		MongoCollection<Document> coleccionOrigen = mongoTemplate.getCollection(origen);
		MongoCollection<Document> coleccionDestino = mongoTemplate.getCollection(destino);
		ReplaceOptions opcionesUpsert = new ReplaceOptions().upsert(true);
		for (Document documento : coleccionOrigen.find()) {
			coleccionDestino.replaceOne(Filters.eq("_id", documento.get("_id")), documento, opcionesUpsert);
		}
		coleccionOrigen.drop();
	}
}
