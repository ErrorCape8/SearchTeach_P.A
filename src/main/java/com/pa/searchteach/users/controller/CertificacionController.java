package com.pa.searchteach.users.controller;

import java.time.LocalDateTime;
import java.util.List;

import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import com.pa.searchteach.common.exception.NotFoundException;
import com.pa.searchteach.users.dto.CertificacionResponse;
import com.pa.searchteach.users.model.CertificacionDocente;
import com.pa.searchteach.users.repository.CertificacionDocenteRepository;
import com.pa.searchteach.users.repository.UserRepository;

@RestController
public class CertificacionController {
	private final CertificacionDocenteRepository repository;
	private final UserRepository users;

	public CertificacionController(CertificacionDocenteRepository repository, UserRepository users) {
		this.repository = repository;
		this.users = users;
	}

	@GetMapping("/api/usuarios/perfil/certificaciones")
	public List<CertificacionResponse> propias(@AuthenticationPrincipal String docenteId) {
		return repository.findByDocenteIdOrderByCreadaEnDesc(docenteId).stream().map(this::response).toList();
	}

	@PostMapping(value = "/api/usuarios/perfil/certificaciones", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
	public CertificacionResponse crear(
			@AuthenticationPrincipal String docenteId,
			@RequestParam String dondeLaDio,
			@RequestParam String duracion,
			@RequestParam String lugar,
			@RequestPart("pdf") MultipartFile pdf) throws java.io.IOException {
		if (users.findById(docenteId).filter(u -> u.getRol() != null
				&& u.getRol().toLowerCase().contains("docente")).isEmpty()) {
			throw new org.springframework.web.server.ResponseStatusException(
					org.springframework.http.HttpStatus.FORBIDDEN, "Solo los docentes pueden registrar certificaciones.");
		}
		if (pdf.isEmpty() || !"application/pdf".equalsIgnoreCase(pdf.getContentType()) || pdf.getSize() > 10 * 1024 * 1024) {
			throw new IllegalArgumentException("Adjunta un PDF válido de máximo 10 MB.");
		}
		CertificacionDocente item = new CertificacionDocente();
		item.setDocenteId(docenteId);
		item.setDondeLaDio(dondeLaDio.trim());
		item.setDuracion(duracion.trim());
		item.setLugar(lugar.trim());
		item.setNombreArchivo(pdf.getOriginalFilename() == null ? "certificado.pdf" : pdf.getOriginalFilename());
		item.setTipoContenido("application/pdf");
		item.setPdf(pdf.getBytes());
		return response(repository.save(item));
	}

	@GetMapping("/api/admin/certificaciones")
	public List<CertificacionResponse> todas() {
		return repository.findAllByOrderByCreadaEnDesc().stream().map(this::response).toList();
	}

	@PatchMapping("/api/admin/certificaciones/{id}")
	public CertificacionResponse revisar(@PathVariable String id, @RequestParam String estado) {
		if (!List.of("APROBADA", "RECHAZADA").contains(estado)) {
			throw new IllegalArgumentException("El estado de revisión no es válido.");
		}
		CertificacionDocente item = repository.findById(id)
				.orElseThrow(() -> new NotFoundException("Certificación no encontrada."));
		item.setEstado(estado);
		item.setRevisadaEn(LocalDateTime.now());
		return response(repository.save(item));
	}

	@GetMapping("/api/admin/certificaciones/{id}/pdf")
	public ResponseEntity<byte[]> pdf(@PathVariable String id) {
		CertificacionDocente item = repository.findById(id)
				.orElseThrow(() -> new NotFoundException("Certificación no encontrada."));
		return ResponseEntity.ok()
				.header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + item.getNombreArchivo() + "\"")
				.contentType(MediaType.APPLICATION_PDF).body(item.getPdf());
	}

	private CertificacionResponse response(CertificacionDocente item) {
		return new CertificacionResponse(item.getId(), item.getDocenteId(), item.getDondeLaDio(),
				item.getLugar(), item.getDuracion(), item.getNombreArchivo(), item.getEstado(), item.getCreadaEn());
	}
}
