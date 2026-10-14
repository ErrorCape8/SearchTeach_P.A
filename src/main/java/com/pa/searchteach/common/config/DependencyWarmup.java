package com.pa.searchteach.common.config;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.redis.core.RedisCallback;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

/** Opens the database connections during service startup instead of on the first user request. */
@Component
public class DependencyWarmup implements ApplicationRunner {

	private final MongoTemplate mongoTemplate;
	private final StringRedisTemplate redisTemplate;

	public DependencyWarmup(MongoTemplate mongoTemplate, StringRedisTemplate redisTemplate) {
		this.mongoTemplate = mongoTemplate;
		this.redisTemplate = redisTemplate;
	}

	@Override
	public void run(ApplicationArguments args) {
		mongoTemplate.executeCommand("{ ping: 1 }");
		redisTemplate.execute((RedisCallback<String>) connection -> connection.ping());
	}
}
