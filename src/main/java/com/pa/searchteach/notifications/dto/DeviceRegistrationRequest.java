package com.pa.searchteach.notifications.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record DeviceRegistrationRequest(
        @NotBlank @Size(max = 4096) String token,
        @NotBlank @Size(max = 20) String platform) {}
