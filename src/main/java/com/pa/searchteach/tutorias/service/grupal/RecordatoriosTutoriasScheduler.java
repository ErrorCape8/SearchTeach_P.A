package com.pa.searchteach.tutorias.service.grupal;

import java.time.LocalDateTime;

import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.repository.SesionTutoriaRepositorio;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import static com.pa.searchteach.tutorias.service.grupal.RelojTutorias.ahora;

/** Avisa a docentes y estudiantes de las tutorías que empiezan pronto. */
@Component
public class RecordatoriosTutoriasScheduler {

	private final SesionTutoriaRepositorio sesiones;
	private final NotificationService notificationService;

	public RecordatoriosTutoriasScheduler(
			SesionTutoriaRepositorio sesiones,
			NotificationService notificationService) {
		this.sesiones = sesiones;
		this.notificationService = notificationService;
	}

	@Scheduled(fixedDelay = 30000)
	public void notificarTutoriasProximas() {
		LocalDateTime ahora = ahora();
		LocalDateTime limite = ahora.plusMinutes(30);
		sesiones.findAll().stream()
				.filter(sesion -> !"FINALIZADA".equals(sesion.estadoClase()))
				.filter(sesion -> !sesion.fechaInicio().isBefore(ahora)
						&& !sesion.fechaInicio().isAfter(limite))
				.forEach(sesion -> {
					String materia = sesion.materia() == null || sesion.materia().isBlank()
							? "tutoría" : sesion.materia();
					String hora = sesion.fechaInicio().format(
							java.time.format.DateTimeFormatter.ofPattern("dd/MM HH:mm"));
					String mensaje = "Tu tutoría de " + materia + " comienza el "
							+ hora + ". Prepárate para ingresar.";
					notificationService.notifyUserOnce(
							sesion.docenteId(), "Tutoría próxima", mensaje, "/docente");
					sesion.estudianteIds().forEach(estudianteId -> notificationService.notifyUserOnce(
							estudianteId, "Tutoría próxima", mensaje, "/estudiante"));
				});
	}
}
