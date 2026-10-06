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
	}

	@Test
	void leavesExistingUsersCollectionUntouched() {
		when(mongoTemplate.collectionExists("users")).thenReturn(true);

		initializer.run(new DefaultApplicationArguments(new String[0]));

		verify(mongoTemplate, never()).createCollection("users");
	}
}
