package com.pa.searchteach.users.dto;

public class UserUpdateRequest {
	private String nombre;
	private String correo;
	private String telefono;
	private String rol;
	private String estado;
	private String carrera;
	private java.util.List<String> titulosAcademicos;
	private String nuevaContrasena;

	public UserUpdateRequest() {
	}

	public UserUpdateRequest(String nombre, String correo, String telefono, String rol, String estado, String nuevaContrasena) {
		this.nombre = nombre;
		this.correo = correo;
		this.telefono = telefono;
		this.rol = rol;
		this.estado = estado;
		this.nuevaContrasena = nuevaContrasena;
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
		this.titulosAcademicos = titulosAcademicos;
	}

	public String getNuevaContrasena() {
		return nuevaContrasena;
	}

	public void setNuevaContrasena(String nuevaContrasena) {
		this.nuevaContrasena = nuevaContrasena;
	}
}
