package com.pa.searchteach.tutorias.service.colectivas;

import java.util.ArrayList;
import java.util.List;

import com.mongodb.client.MongoCollection;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import org.bson.Document;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.stereotype.Component;

/**
 * Mueve a {@code grupos_proyectos_aula_invalidos} los documentos de {@code grupos_proyectos_aula}
 * que no cumplen los campos obligatorios de TutoriaColectiva. Un solo documento inválido hace
 * fallar findAll() y con él la pantalla "Proyectos de aula" (HTTP 400) y el scheduler de avisos.
 * No se borra nada: los documentos quedan en la colección de cuarentena.
 */
@Component
@Order(Integer.MAX_VALUE)
public class SaneadorGruposProyectosAula implements ApplicationRunner {

	private static final Logger LOGGER = LoggerFactory.getLogger(SaneadorGruposProyectosAula.class);
	private static final String COLECCION = "grupos_proyectos_aula";
	private static final String CUARENTENA = "grupos_proyectos_aula_invalidos";

	private final MongoTemplate mongoTemplate;

	public SaneadorGruposProyectosAula(MongoTemplate mongoTemplate) {
		this.mongoTemplate = mongoTemplate;
	}

	@Override
	public void run(ApplicationArguments args) {
		try {
			MongoCollection<Document> origen = mongoTemplate.getCollection(COLECCION);
			MongoCollection<Document> destino = mongoTemplate.getCollection(CUARENTENA);
			List<Object> movidos = new ArrayList<>();
			for (Document documento : origen.find()) {
				if (!esValido(documento)) {
					Object id = documento.get("_id");
					destino.replaceOne(new Document("_id", id), documento,
							new com.mongodb.client.model.ReplaceOptions().upsert(true));
					movidos.add(id);
				}
			}
			if (!movidos.isEmpty()) {
				origen.deleteMany(new Document("_id", new Document("$in", movidos)));
				LOGGER.warn("Se movieron {} documentos inválidos de {} a {}: {}",
						movidos.size(), COLECCION, CUARENTENA, movidos);
			}
		} catch (Exception exception) {
			LOGGER.error("No se pudo sanear la colección {}.", COLECCION, exception);
		}
	}

	/**
	 * Valida el documento igual que lo hará findAll(): lo convierte a TutoriaColectiva, de modo que
	 * se ejecutan los constructores compactos de TutoriaColectiva y de cada ProyectoAula (cinco
	 * docentes de apoyo distintos, responsables válidos, semestre 1-6, estadoCierre válido,
	 * máximo cuatro estudiantes sin repetir, etc.). Cualquier excepción manda el documento a cuarentena.
	 */
	private boolean esValido(Document d) {
		try {
			return mongoTemplate.getConverter().read(TutoriaColectiva.class, d) != null;
		} catch (RuntimeException exception) {
			LOGGER.warn("Documento {} inválido en {}: {}", d.get("_id"), COLECCION, exception.toString());
			return false;
		}
	}
}
