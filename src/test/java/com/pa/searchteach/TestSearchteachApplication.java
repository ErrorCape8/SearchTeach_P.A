package com.pa.searchteach;

import org.springframework.boot.SpringApplication;

public class TestSearchteachApplication {

	public static void main(String[] args) {
		SpringApplication.from(SearchteachApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
