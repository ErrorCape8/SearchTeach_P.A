package com.pa.searchteach.users.model;

import java.time.LocalDateTime;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "certificaciones_docentes")
public class CertificacionDocente {
	@Id
	private String id;
	private String docenteId;
	private String dondeLaDio;
	private String lugar;
	private String duracion;
	private String nombreArchivo;
	private String tipoContenido;
	private byte[] pdf;
	private String estado = "PENDIENTE";
	private LocalDateTime creadaEn = LocalDateTime.now();
	private LocalDateTime revisadaEn;

	public String getId() { return id; }
	public void setId(String id) { this.id = id; }
	public String getDocenteId() { return docenteId; }
	public void setDocenteId(String docenteId) { this.docenteId = docenteId; }
	public String getDondeLaDio() { return dondeLaDio; }
	public void setDondeLaDio(String dondeLaDio) { this.dondeLaDio = dondeLaDio; }
	public String getLugar() { return lugar; }
	public void setLugar(String lugar) { this.lugar = lugar; }
	public String getDuracion() { return duracion; }
	public void setDuracion(String duracion) { this.duracion = duracion; }
	public String getNombreArchivo() { return nombreArchivo; }
	public void setNombreArchivo(String nombreArchivo) { this.nombreArchivo = nombreArchivo; }
	public String getTipoContenido() { return tipoContenido; }
	public void setTipoContenido(String tipoContenido) { this.tipoContenido = tipoContenido; }
	public byte[] getPdf() { return pdf; }
	public void setPdf(byte[] pdf) { this.pdf = pdf; }
	public String getEstado() { return estado; }
	public void setEstado(String estado) { this.estado = estado; }
	public LocalDateTime getCreadaEn() { return creadaEn; }
	public void setCreadaEn(LocalDateTime creadaEn) { this.creadaEn = creadaEn; }
	public LocalDateTime getRevisadaEn() { return revisadaEn; }
	public void setRevisadaEn(LocalDateTime revisadaEn) { this.revisadaEn = revisadaEn; }
}
