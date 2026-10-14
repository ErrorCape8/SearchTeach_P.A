package com.pa.searchteach.users.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.data.mongodb.core.MongoTemplate;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class UserCollectionInitializerTest {

	private final MongoTemplate mongoTemplate = mock(MongoTemplate.class);
	private final UserCollectionInitializer initializer = new UserCollectionInitializer(mongoTemplate);

	@Test
	void createsUsersCollectionWhenItDoesNotExist() {
		when(mongoTemplate.collectionExists("users")).thenReturn(false);

		initializer.run(new DefaultApplicationArguments(new String[0]));

		verify(mongoTemplate).createCollection("users");
		verify(mongoTemplate).createCollection("program_leaders");
		verify(mongoTemplate).createCollection("coordinators");
		verify(mongoTemplate).createCollection("sesiones_tutoria");
		verify(mongoTemplate).createCollection("tutorias_colectivas");
		verify(mongoTemplate).createCollection("informes_avance_proyecto");
	}

	@Test
	void leavesExistingUsersCollectionUntouched() {
		when(mongoTemplate.collectionExists("users")).thenReturn(true);
		when(mongoTemplate.collectionExists("program_leaders")).thenReturn(true);
		when(mongoTemplate.collectionExists("coordinators")).thenReturn(true);
		when(mongoTemplate.collectionExists("sesiones_tutoria")).thenReturn(true);
		when(mongoTemplate.collectionExists("tutorias_colectivas")).thenReturn(true);
		when(mongoTemplate.collectionExists("informes_avance_proyecto")).thenReturn(true);

		initializer.run(new DefaultApplicationArguments(new String[0]));

		verify(mongoTemplate, never()).createCollection("users");
		verify(mongoTemplate, never()).createCollection("program_leaders");
		verify(mongoTemplate, never()).createCollection("coordinators");
		verify(mongoTemplate, never()).createCollection("sesiones_tutoria");
		verify(mongoTemplate, never()).createCollection("tutorias_colectivas");
		verify(mongoTemplate, never()).createCollection("informes_avance_proyecto");
	}
}
