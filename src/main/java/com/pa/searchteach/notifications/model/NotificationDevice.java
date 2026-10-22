package com.pa.searchteach.notifications.model;

import java.time.LocalDateTime;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document(collection = "notification_devices")
public class NotificationDevice {
    @Id private String id;
    private String userId;
    private String token;
    private String platform;
    private LocalDateTime updatedAt;

    public NotificationDevice() {}
    public NotificationDevice(String userId, String token, String platform) {
        this.userId = userId;
        this.token = token;
        this.platform = platform;
        this.updatedAt = LocalDateTime.now();
    }
    public String getId() { return id; }
    public String getUserId() { return userId; }
    public String getToken() { return token; }
    public String getPlatform() { return platform; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUserId(String userId) { this.userId = userId; }
    public void setPlatform(String platform) { this.platform = platform; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }
}
