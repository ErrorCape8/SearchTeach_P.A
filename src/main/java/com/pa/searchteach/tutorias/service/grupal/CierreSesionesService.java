package com.pa.searchteach.tutorias.service.grupal;

import java.time.LocalDateTime;

import com.pa.searchteach.tutorias.model.SesionTutoria;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import com.pa.searchteach.tutorias.service.LiveKitRoomAdminService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import static com.pa.searchteach.tutorias.service.grupal.RelojTutorias.ahora;

/** Cierra automáticamente las sesiones cuyo horario ya terminó. */
@Service
public class CierreSesionesService {

	private final SesionTutoriaRepositorio sesiones;
	private final LiveKitRoomAdminService liveKitRooms;
	private final ActualizacionesTutoriasService actualizacionesTutorias;

	public CierreSesionesService(
			SesionTutoriaRepositorio sesiones,
			LiveKitRoomAdminService liveKitRooms,
			ActualizacionesTutoriasService actualizacionesTutorias) {
		this.sesiones = sesiones;
		this.liveKitRooms = liveKitRooms;
		this.actualizacionesTutorias = actualizacionesTutorias;
	}

	public SesionTutoria cerrarSiVencida(SesionTutoria sesion) {
		if (!"FINALIZADA".equals(sesion.estadoClase()) && !ahora().isBefore(sesion.fechaFin())) {
			SesionTutoria cerrada = sesiones.save(sesion.cerrar("FINALIZACION_AUTOMATICA", sesion.fechaFin()));
			liveKitRooms.closeGroupTutoringRoom(sesion.id());
			actualizacionesTutorias.publicar("FINALIZADA", sesion.id());
			return cerrada;
		}
		return sesion;
	}

	@Scheduled(fixedDelay = 30000)
	public void finalizarClasesVencidas() {
		LocalDateTime ahora = ahora();
		sesiones.findAll().stream()
				.filter(sesion -> !"FINALIZADA".equals(sesion.estadoClase()))
				.filter(sesion -> !sesion.fechaFin().isAfter(ahora))
				.forEach(this::cerrarSiVencida);
	}
}
