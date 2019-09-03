FROM nginx:latest

RUN usermod -u 1000 www-data

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]