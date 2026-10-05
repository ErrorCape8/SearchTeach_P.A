package com.pa.searchteach;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;

@Import(TestcontainersConfiguration.class)
@SpringBootTest(properties = "app.auth.jwt.secret=test-only-secret-key-with-at-least-32-bytes")
class SearchteachApplicationTests {

	@Test
	void contextLoads() {
	}

}
