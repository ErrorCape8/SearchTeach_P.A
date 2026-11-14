package com.pa.searchteach.tutorias.service.colectivas;

import java.time.LocalDateTime;
import java.util.UUID;

import com.pa.searchteach.notifications.service.NotificationService;
import com.pa.searchteach.tutorias.model.MensajeProyectoAula;
import com.pa.searchteach.tutorias.model.ProyectoAula;
import com.pa.searchteach.tutorias.model.TutoriaColectiva;
import com.pa.searchteach.tutorias.repository.MensajeProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.SesionProyectoAulaRepositorio;
import com.pa.searchteach.tutorias.repository.TutoriaColectivaRepositorio;
import com.pa.searchteach.tutorias.service.ActualizacionesTutoriasService;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** Publica en el chat el aviso de las reuniones de proyecto que ya comenzaron. */
@Component
public class AvisosReunionesProyectoScheduler {

	private final TutoriaColectivaRepositorio tutoriaColectivaRepositorio;
	private final SesionProyectoAulaRepositorio sesionProyectoRepositorio;
	private final MensajeProyectoAulaRepositorio mensajeProyectoRepositorio;
	private final NotificationService notificationService;
	private final ActualizacionesTutoriasService actualizacionesTutoriasService;

	public AvisosReunionesProyectoScheduler(
			TutoriaColectivaRepositorio tutoriaColectivaRepositorio,
			SesionProyectoAulaRepositorio sesionProyectoRepositorio,
			MensajeProyectoAulaRepositorio mensajeProyectoRepositorio,
			NotificationService notificationService,
			ActualizacionesTutoriasService actualizacionesTutoriasService) {
		this.tutoriaColectivaRepositorio = tutoriaColectivaRepositorio;
		this.sesionProyectoRepositorio = sesionProyectoRepositorio;
		this.mensajeProyectoRepositorio = mensajeProyectoRepositorio;
		this.notificationService = notificationService;
		this.actualizacionesTutoriasService = actualizacionesTutoriasService;
	}

	@Scheduled(fixedDelay = 30000)
	public void publicarAvisosDeReunionesIniciadas() {
		LocalDateTime ahora = LocalDateTime.now();
		for (TutoriaColectiva tutoria : tutoriaColectivaRepositorio.findAll()) {
			TutoriaColectiva actual = tutoria;
			for (ProyectoAula proyecto : tutoria.proyectos()) {
				if (proyecto.fechaReunion() == null || proyecto.fechaReunion().isAfter(ahora)
						|| proyecto.reunionMensajePublicadoEn() != null || proyecto.reunionSesionId() == null) continue;
				if (sesionProyectoRepositorio.findByIdAndTutoriaColectivaIdAndProyectoId(
						proyecto.reunionSesionId(), tutoria.id(), proyecto.proyectoId()).isEmpty()) continue;
				String roomId = "searchteach-pa-" + proyecto.proyectoId();
				mensajeProyectoRepositorio.save(new MensajeProyectoAula(
						UUID.randomUUID().toString(), tutoria.id(), proyecto.proyectoId(),
						proyecto.reunionSesionId(), proyecto.docenteResponsableId(),
						"La reunión de proyecto de aula está comenzando. Entra a la sala desde este mensaje.",
						null, null, null, null, ahora, "REUNION", roomId));
				ProyectoAula actualizado = proyecto.marcarMensajeReunionPublicado(ahora);
				actual = actual.actualizarProyecto(actualizado);
				tutoriaColectivaRepositorio.save(actual);
				actualizacionesTutoriasService.publicar("PROYECTO_CAMBIO", tutoria.id());
				java.util.stream.Stream.concat(proyecto.estudianteIds().stream(),
						java.util.stream.Stream.of(proyecto.docenteResponsableId()))
						.distinct().forEach(destinatario -> notificationService.notifyUser(destinatario,
								"La reunión de proyecto de aula comenzó",
								"Entra al chat de " + proyecto.nombre() + " para unirte a la reunión.",
								"/notificaciones"));
			}
		}
	}
}
