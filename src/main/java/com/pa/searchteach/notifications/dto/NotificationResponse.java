package com.pa.searchteach.notifications.dto;

import com.pa.searchteach.notifications.model.Notification;
import java.time.LocalDateTime;

public record NotificationResponse(String id, String title, String message, String route,
                                   LocalDateTime createdAt, boolean read) {
    public static NotificationResponse from(Notification item) {
        return new NotificationResponse(item.getId(), item.getTitle(), item.getMessage(),
                item.getRoute(), item.getCreatedAt(), item.isRead());
    }
}
