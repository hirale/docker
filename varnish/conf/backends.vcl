backend default {
    .host = "nginx";
    .port = "80";
    .first_byte_timeout = 300s;
    .between_bytes_timeout = 300s;
}

backend magento2 {
    .host = "nginx";
    .port = "80";
    .first_byte_timeout = 600s;
    .probe = {
        .url = "/health_check.php";
        .timeout = 2s;
        .interval = 5s;
        .window = 10;
        .threshold = 5;
    }
}

backend admin {
    .host = "nginx";
    .port = "80";
    .first_byte_timeout = 300s;
    .between_bytes_timeout = 300s;
}
