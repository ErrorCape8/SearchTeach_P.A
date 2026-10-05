package com.pa.searchteach;

import org.springframework.boot.SpringApplication;

public class TestSearchteachApplication {

	public static void main(String[] args) {
		SpringApplication.from(SearchTeachApplication::main).with(TestcontainersConfiguration.class).run(args);
	}

}
