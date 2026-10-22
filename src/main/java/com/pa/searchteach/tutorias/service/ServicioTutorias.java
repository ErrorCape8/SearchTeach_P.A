package com.pa.searchteach.tutorias.service;

import java.util.List;

import com.pa.searchteach.tutorias.dto.PropuestaHorario;
import com.pa.searchteach.tutorias.dto.RegistroAsistencia;
import com.pa.searchteach.tutorias.dto.SolicitudTutoria;
import com.pa.searchteach.tutorias.model.Tutoria;

public interface ServicioTutorias {

	Tutoria solicitar(SolicitudTutoria solicitud, String usuarioId);

	List<Tutoria> listarDelUsuario(String usuarioId);

	Tutoria buscar(String id, String usuarioId);

	Tutoria aceptar(String id, String usuarioId);

	Tutoria proponerHorario(String id, PropuestaHorario propuesta, String usuarioId);

	Tutoria confirmarAlternativa(String id, String usuarioId);

	Tutoria cancelar(String id, String usuarioId);

	Tutoria iniciar(String id, String usuarioId);

	Tutoria finalizar(String id, RegistroAsistencia asistencia, String usuarioId);
}
