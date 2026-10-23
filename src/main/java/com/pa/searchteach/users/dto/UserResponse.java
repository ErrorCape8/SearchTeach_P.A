package com.pa.searchteach.users.dto;

public class UserResponse {
	private String id;
	private String nombre;
	private String correo;
	private String telefono;
	private String rol;
	private String estado;
	private String carrera;
	private java.util.List<String> titulosAcademicos = java.util.List.of();

	public UserResponse() {
	}

	public UserResponse(String id, String nombre, String correo, String telefono, String rol, String estado) {
		this(id, nombre, correo, telefono, rol, estado, "");
	}

	public UserResponse(String id, String nombre, String correo, String telefono, String rol, String estado, String carrera) {
		this(id, nombre, correo, telefono, rol, estado, carrera, java.util.List.of());
	}

	public UserResponse(String id, String nombre, String correo, String telefono, String rol, String estado, String carrera, java.util.List<String> titulosAcademicos) {
		this.id = id;
		this.nombre = nombre;
		this.correo = correo;
		this.telefono = telefono;
		this.rol = rol;
		this.estado = estado;
		this.carrera = carrera;
		this.titulosAcademicos = titulosAcademicos == null ? java.util.List.of() : java.util.List.copyOf(titulosAcademicos);
	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
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
		return titulosAcademicos;
	}

	public void setTitulosAcademicos(java.util.List<String> titulosAcademicos) {
		this.titulosAcademicos = titulosAcademicos == null ? java.util.List.of() : java.util.List.copyOf(titulosAcademicos);
	}
}
