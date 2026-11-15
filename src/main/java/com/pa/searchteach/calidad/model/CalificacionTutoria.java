package com.pa.searchteach.calidad.model;

import java.time.LocalDateTime;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Calificación en estrellas (1 a 5) otorgada por un estudiante tras una tutoría.
 * El estudianteId se almacena únicamente para evitar votos duplicados por sesión,
 * pero nunca se expone en las vistas de Dirección/Calidad.
 */
@Document(collection = "calificaciones_tutoria")
public class CalificacionTutoria {

	@Id
	private String id;
	private String sesionId;
	private String estudianteId;
	private String tutorId;
	private String materia;
	private int estrellas; // 1 a 5
	private String comentario;
	private LocalDateTime fechaCreacion;

	public CalificacionTutoria() {
	}

	public CalificacionTutoria(
			String sesionId,
			String estudianteId,
			String tutorId,
			String materia,
			int estrellas,
			String comentario,
			LocalDateTime fechaCreacion) {
		this.sesionId = sesionId;
		this.estudianteId = estudianteId;
		this.tutorId = tutorId;
		this.materia = materia;
		this.estrellas = estrellas;
		this.comentario = comentario;
		this.fechaCreacion = fechaCreacion;
	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public String getSesionId() {
		return sesionId;
	}

	public void setSesionId(String sesionId) {
		this.sesionId = sesionId;
	}

	public String getEstudianteId() {
		return estudianteId;
	}

	public void setEstudianteId(String estudianteId) {
		this.estudianteId = estudianteId;
	}

	public String getTutorId() {
		return tutorId;
	}

	public void setTutorId(String tutorId) {
		this.tutorId = tutorId;
	}

	public String getMateria() {
		return materia;
	}

	public void setMateria(String materia) {
		this.materia = materia;
	}

	public int getEstrellas() {
		return estrellas;
	}

	public void setEstrellas(int estrellas) {
		this.estrellas = estrellas;
	}

	public String getComentario() {
		return comentario;
	}

	public void setComentario(String comentario) {
		this.comentario = comentario;
	}

	public LocalDateTime getFechaCreacion() {
		return fechaCreacion;
	}

	public void setFechaCreacion(LocalDateTime fechaCreacion) {
		this.fechaCreacion = fechaCreacion;
	}
}
