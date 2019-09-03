# Docker LNMP

Run lnmp env with docker

nginx-ssl->(varnish)?->nginx->php

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

You need [Docker](https://docs.docker.com/docker-for-windows/install/) to run this. 

### Installing

A step by step series of examples that tell you how to get a development env running

- copy .env.example to .env
- set up your domain conf in nginx&nginx-ssl
- set up your ssl

```console
foo@bar:~$ cp .env.example .env 
foo@bar:~$ cp nginx/conf/sites-enabled/domain.com.conf.example nginx/conf/sites-enabled/your-domain.conf
foo@bar:~$ mkdir nginx-ssl/ssl 
foo@bar:~$ cp nginx-ssl/sites-enabled/domain.com.conf.example nginx/conf/sites-enabled/your-domain.conf
```
When you finished, you can run it up.

```
docker-compose -p the_name_u_want up -d
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details