package com.pa.searchteach.notifications.service;

import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.pa.searchteach.notifications.model.Notification;
import com.pa.searchteach.notifications.model.NotificationDevice;
import com.pa.searchteach.notifications.repository.NotificationDeviceRepository;
import com.pa.searchteach.notifications.repository.NotificationRepository;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.stereotype.Service;

@Service
public class NotificationService {
    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);
    private final NotificationRepository notifications;
    private final NotificationDeviceRepository devices;
    private final ObjectProvider<FirebaseMessaging> firebaseMessaging;

    public NotificationService(NotificationRepository notifications,
            NotificationDeviceRepository devices,
            ObjectProvider<FirebaseMessaging> firebaseMessaging) {
        this.notifications = notifications;
        this.devices = devices;
        this.firebaseMessaging = firebaseMessaging;
    }

    public List<Notification> listForUser(String userId) {
        return notifications.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public long unreadCount(String userId) {
        return notifications.countByUserIdAndReadFalse(userId);
    }

    public void markRead(String notificationId, String userId) {
        Notification notification = notifications.findById(notificationId)
                .filter(item -> item.getUserId().equals(userId))
                .orElseThrow(() -> new org.springframework.web.server.ResponseStatusException(
                        org.springframework.http.HttpStatus.NOT_FOUND, "No se encontro el aviso."));
        notification.setRead(true);
        notifications.save(notification);
    }

    public void markAllRead(String userId) {
        List<Notification> items = notifications.findByUserIdOrderByCreatedAtDesc(userId);
        items.forEach(item -> item.setRead(true));
        notifications.saveAll(items);
    }

    public void registerDevice(String userId, String token, String platform) {
        NotificationDevice device = devices.findByToken(token)
                .orElseGet(() -> new NotificationDevice(userId, token, platform));
        device.setUserId(userId);
        device.setPlatform(platform);
        device.setUpdatedAt(java.time.LocalDateTime.now());
        devices.save(device);
    }

    public void removeDevice(String userId, String token) {
        devices.deleteByUserIdAndToken(userId, token);
    }

    public void notifyUser(String userId, String title, String message, String route) {
        if (userId == null || userId.isBlank()) return;
        Notification saved = notifications.save(new Notification(userId, title, message, route));
        FirebaseMessaging sender = firebaseMessaging.getIfAvailable();
        if (sender == null) return;
        for (NotificationDevice device : devices.findByUserId(userId)) {
            try {
                sender.send(Message.builder().setToken(device.getToken())
                        .setNotification(com.google.firebase.messaging.Notification.builder()
                                .setTitle(title).setBody(message).build())
                        .putData("route", route == null ? "/notificaciones" : route)
                        .putData("notificationId", saved.getId()).build());
            } catch (FirebaseMessagingException exception) {
                log.warn("No se pudo enviar la notificacion push al dispositivo registrado: {}",
                        exception.getMessagingErrorCode());
            }
        }
    }
}
