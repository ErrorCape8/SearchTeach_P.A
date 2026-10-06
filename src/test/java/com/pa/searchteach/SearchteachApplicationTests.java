package com.pa.searchteach;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.data.mongodb.core.MongoTemplate;

import static org.assertj.core.api.Assertions.assertThat;

@Import(TestcontainersConfiguration.class)
@SpringBootTest(properties = "app.auth.jwt.secret=test-only-secret-key-with-at-least-32-bytes")
class SearchteachApplicationTests {

	@Autowired
	private MongoTemplate mongoTemplate;

	@Test
	void contextLoads() {
	}

	@Test
	void createsUsersCollectionOnStartup() {
		assertThat(mongoTemplate.collectionExists("users")).isTrue();
	}

}
