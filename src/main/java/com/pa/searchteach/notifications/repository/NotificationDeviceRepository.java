package com.pa.searchteach.notifications.repository;

import com.pa.searchteach.notifications.model.NotificationDevice;
import java.util.List;
import java.util.Optional;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface NotificationDeviceRepository extends MongoRepository<NotificationDevice, String> {
    List<NotificationDevice> findByUserId(String userId);
    Optional<NotificationDevice> findByToken(String token);
    void deleteByUserIdAndToken(String userId, String token);
}
