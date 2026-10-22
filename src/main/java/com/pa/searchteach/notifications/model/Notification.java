package com.pa.searchteach.notifications.model;

import java.time.LocalDateTime;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "notifications")
public class Notification {
    @Id private String id;
    private String userId;
    private String title;
    private String message;
    private String route;
    private LocalDateTime createdAt;
    private boolean read;

    public Notification() {}
    public Notification(String userId, String title, String message, String route) {
        this.userId = userId;
        this.title = title;
        this.message = message;
        this.route = route;
        this.createdAt = LocalDateTime.now();
        this.read = false;
    }
    public String getId() { return id; }
    public String getUserId() { return userId; }
    public String getTitle() { return title; }
    public String getMessage() { return message; }
    public String getRoute() { return route; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public boolean isRead() { return read; }
    public void setRead(boolean read) { this.read = read; }
}
