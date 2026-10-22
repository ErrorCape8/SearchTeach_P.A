package com.pa.searchteach.notifications.controller;

import com.pa.searchteach.notifications.dto.DeviceRegistrationRequest;
import com.pa.searchteach.notifications.dto.NotificationResponse;
import com.pa.searchteach.notifications.service.NotificationService;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/notificaciones")
public class NotificationController {
    private final NotificationService notificationService;
    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @GetMapping
    public List<NotificationResponse> listarAvisos(@AuthenticationPrincipal String userId) {
        return notificationService.listForUser(userId).stream().map(NotificationResponse::from).toList();
    }

    @GetMapping("/no-leidas/count")
    public Map<String, Long> contarAvisosNoLeidos(@AuthenticationPrincipal String userId) {
        return Map.of("count", notificationService.unreadCount(userId));
    }

    @PatchMapping("/{id}/leida")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void marcarAvisoLeido(@PathVariable String id, @AuthenticationPrincipal String userId) {
        notificationService.markRead(id, userId);
    }

    @PatchMapping("/leidas")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void marcarTodosLosAvisosLeidos(@AuthenticationPrincipal String userId) {
        notificationService.markAllRead(userId);
    }

    @PostMapping("/dispositivos")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void registrarDispositivo(@AuthenticationPrincipal String userId,
            @Valid @RequestBody DeviceRegistrationRequest request) {
        notificationService.registerDevice(userId, request.token(), request.platform());
    }

    @DeleteMapping("/dispositivos")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void eliminarDispositivo(@AuthenticationPrincipal String userId,
            @RequestParam String token) {
        notificationService.removeDevice(userId, token);
    }
}
