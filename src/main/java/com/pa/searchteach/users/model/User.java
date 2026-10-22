package com.pa.searchteach.users.model;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "users")
public class User {

	@Id
	private String id;
	private String passwordHash;
	private String nombre;
	private String correo;
	private String telefono;
	private String rol;
	private String estado;
	private String carrera;
	private java.util.List<String> titulosAcademicos = java.util.List.of();
	private java.util.List<String> materiasAsignadas = java.util.List.of();

	public User() {
	}

	public User(String id, String passwordHash, String nombre, String correo, String telefono, String rol, String estado) {
		this(id, passwordHash, nombre, correo, telefono, rol, estado, "");
	}

	public User(String id, String passwordHash, String nombre, String correo, String telefono, String rol, String estado, String carrera) {
		this.id = id;
		this.passwordHash = passwordHash;
		this.nombre = nombre;
		this.correo = correo;
		this.telefono = telefono;
		this.rol = rol;
		this.estado = estado;
		this.carrera = carrera;
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

	public String getRol() {
		return rol;
	}

	public void setRol(String rol) {
		this.rol = rol;
	}

	public String getEstado() {
		return estado;
	}

	public void setEstado(String estado) {
		this.estado = estado;
	}

	public String getCarrera() {
		return carrera;
	}

	public void setCarrera(String carrera) {
		this.carrera = carrera;
	}

	public java.util.List<String> getTitulosAcademicos() {
		return titulosAcademicos == null ? java.util.List.of() : java.util.List.copyOf(titulosAcademicos);
	}

	public void setTitulosAcademicos(java.util.List<String> titulosAcademicos) {
		this.titulosAcademicos = titulosAcademicos == null ? java.util.List.of() : java.util.List.copyOf(titulosAcademicos);
	}

	public java.util.List<String> getMateriasAsignadas() {
		return materiasAsignadas == null ? java.util.List.of() : java.util.List.copyOf(materiasAsignadas);
	}

	public void setMateriasAsignadas(java.util.List<String> materiasAsignadas) {
		this.materiasAsignadas = materiasAsignadas == null ? java.util.List.of() : java.util.List.copyOf(materiasAsignadas);
	}
}
