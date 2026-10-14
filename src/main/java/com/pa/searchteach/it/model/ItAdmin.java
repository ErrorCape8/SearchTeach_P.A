package com.pa.searchteach.it.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "it")
public class ItAdmin {

	@Id
	private String id;
	private String passwordHash;
	private String nombre;
	private String correo;
	private String telefono;
	private String programa;
	private String rol;

	public ItAdmin() {
	}

	public ItAdmin(String id, String passwordHash) {
		this.id = id;
		this.passwordHash = passwordHash;
	}

	public ItAdmin(String id, String passwordHash, String nombre, String correo, String telefono, String programa, String rol) {
		this.id = id;
		this.passwordHash = passwordHash;
		this.nombre = nombre;
		this.correo = correo;
		this.telefono = telefono;
		this.programa = programa;
		this.rol = rol;
	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public String getPasswordHash() {
		return passwordHash;
	}

	public void setPasswordHash(String passwordHash) {
		this.passwordHash = passwordHash;
	}

	public String getNombre() {
		return nombre;
	}

	public void setNombre(String nombre) {
		this.nombre = nombre;
	}

	public String getCorreo() {
		return correo;
	}

	public void setCorreo(String correo) {
		this.correo = correo;
	}

	public String getTelefono() {
		return telefono;
	}

	public void setTelefono(String telefono) {
		this.telefono = telefono;
	}

	public String getPrograma() {
		return programa;
	}

	public void setPrograma(String programa) {
		this.programa = programa;
	}

	public String getRol() {
		return rol;
	}

	public void setRol(String rol) {
		this.rol = rol;
	}
}
