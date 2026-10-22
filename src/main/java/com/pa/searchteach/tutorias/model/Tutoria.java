package com.pa.searchteach.tutorias.model;

import java.time.LocalDateTime;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "tutorias")
public class Tutoria {

	@Id
	private String id;
	private String estudianteId;
	private String docenteId;
	private String materia;
	private ModalidadTutoria modalidad;
	private LocalDateTime fechaInicio;
	private LocalDateTime fechaFin;
	private LocalDateTime fechaAlternativaInicio;
	private LocalDateTime fechaAlternativaFin;
	private EstadoTutoria estado;
	private Boolean asistio;

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public String getEstudianteId() {
		return estudianteId;
	}

	public void setEstudianteId(String estudianteId) {
		this.estudianteId = estudianteId;
	}

	public String getDocenteId() {
		return docenteId;
	}

	public void setDocenteId(String docenteId) {
		this.docenteId = docenteId;
	}

	public String getMateria() {
		return materia;
	}

	public void setMateria(String materia) {
		this.materia = materia;
	}

	public ModalidadTutoria getModalidad() {
		return modalidad;
	}

	public void setModalidad(ModalidadTutoria modalidad) {
		this.modalidad = modalidad;
	}

	public LocalDateTime getFechaInicio() {
		return fechaInicio;
	}

	public void setFechaInicio(LocalDateTime fechaInicio) {
		this.fechaInicio = fechaInicio;
	}

	public LocalDateTime getFechaFin() {
		return fechaFin;
	}

	public void setFechaFin(LocalDateTime fechaFin) {
		this.fechaFin = fechaFin;
	}

	public LocalDateTime getFechaAlternativaInicio() {
		return fechaAlternativaInicio;
	}

	public void setFechaAlternativaInicio(LocalDateTime fechaAlternativaInicio) {
		this.fechaAlternativaInicio = fechaAlternativaInicio;
	}

	public LocalDateTime getFechaAlternativaFin() {
		return fechaAlternativaFin;
	}

	public void setFechaAlternativaFin(LocalDateTime fechaAlternativaFin) {
		this.fechaAlternativaFin = fechaAlternativaFin;
	}

	public EstadoTutoria getEstado() {
		return estado;
	}

	public void setEstado(EstadoTutoria estado) {
		this.estado = estado;
	}

	public Boolean getAsistio() {
		return asistio;
	}

	public void setAsistio(Boolean asistio) {
		this.asistio = asistio;
	}
}
