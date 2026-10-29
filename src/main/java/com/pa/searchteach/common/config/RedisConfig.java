package com.pa.searchteach.common.config;

import com.pa.searchteach.tutorias.service.ProyectoAulaChatRedisService;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.listener.ChannelTopic;
import org.springframework.data.redis.listener.RedisMessageListenerContainer;

@Configuration
public class RedisConfig {
	@Bean
	RedisMessageListenerContainer proyectoAulaChatRedisListener(
			RedisConnectionFactory connectionFactory,
			ProyectoAulaChatRedisService listener) {
		RedisMessageListenerContainer container = new RedisMessageListenerContainer();
		container.setConnectionFactory(connectionFactory);
		container.addMessageListener(listener,
				new ChannelTopic(ProyectoAulaChatRedisService.CHANNEL));
		return container;
	}
}
