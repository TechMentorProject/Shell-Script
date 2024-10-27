#!/bin/bash

BUCKET_NAME="techmentor-bucket"
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
AWS_SESSION_TOKEN=""

ssh -i "techmentor.pem" -o StrictHostKeyChecking=no ubuntu@ec2-ip.compute-1.amazonaws.com << EOF
    sudo apt update && sudo apt upgrade –y

    docker --version
    if [ $? = 0 ];
        then
            echo "Instalando Docker"
            sudo apt install docker.io
        else
            echo "Docker já instalado"
    fi

    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker ativado"

    sudo docker pull mysql:5.7
    sudo docker run -d -p 3306:3306 --name ContainerBD -e "MYSQL_DATABASE=techmentor" -e "MYSQL_ROOT_PASSWORD=root" mysql:5.7
    echo "Container de BD criado"

    echo "Coloque a senha do MySQL abaixo (urubu100)"
    sudo docker exec -it ContainerBD bash
    mysql -u root -p

    CREATE DATABASE techmentor;
    USE techmentor;

    CREATE TABLE estado ( idEstado INT AUTO_INCREMENT PRIMARY KEY, regiao VARCHAR(100), UF CHAR(2));

    CREATE TABLE municipio ( idMunicipio INT AUTO_INCREMENT PRIMARY KEY, ano char(4), cidade VARCHAR(100), operadora VARCHAR(100), domiciliosCobertosPercent DECIMAL(10,2), areaCobertaPercent DECIMAL(5,2), tecnologia VARCHAR(50));

    CREATE TABLE estacoesSMP ( idEstacoesSMP INT AUTO_INCREMENT PRIMARY KEY, cidade VARCHAR(255), operadora VARCHAR(255), latitude BIGINT, longitude BIGINT, codigoIBGE VARCHAR(255), tecnologia VARCHAR(255));


    CREATE TABLE censoIBGE ( idCensoIBGE INT AUTO_INCREMENT PRIMARY KEY, cidade VARCHAR(100), area DECIMAL(10,2), densidadeDemografica DECIMAL(10,2));


    CREATE TABLE projecaoPopulacional ( idProjecaoPopulacional INT AUTO_INCREMENT PRIMARY KEY, estado varchar(100), ano INT, projecao INT);

    CREATE TABLE empresa ( idEmpresa INT AUTO_INCREMENT PRIMARY KEY, nomeEmpresa VARCHAR(100) NOT NULL, nomeResponsavel VARCHAR(100), cnpj VARCHAR(20) NOT NULL UNIQUE, emailResponsavel VARCHAR(100) NOT NULL, senha VARCHAR(100) NOT NULL);


    CREATE TABLE cargo ( idCargo INT AUTO_INCREMENT PRIMARY KEY, nomeCargo VARCHAR(100) NOT NULL, salario DECIMAL(10,2) NOT NULL, idEmpresa INT, FOREIGN KEY (idEmpresa) REFERENCES empresa(idEmpresa));


    CREATE TABLE usuario ( idUsuario INT AUTO_INCREMENT PRIMARY KEY, email VARCHAR(100), nomeUsuario VARCHAR(100), cpf VARCHAR(20), senha VARCHAR(100), idEmpresa INT, idCargo INT, FOREIGN KEY (idEmpresa) REFERENCES empresa(idEmpresa), FOREIGN KEY (idCargo) REFERENCES cargo(idCargo));

    ALTER TABLE municipio CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    ALTER TABLE projecaoPopulacional CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

    exit
    exit
    echo "Comandos SQL usados com sucesso"
    
    mkdir docker-java
    cd docker-java
    touch Dockerfile
    echo -e "FROM openjdk:21-jre\nWORKDIR /app\nCOPY techmentor.jar app.jar\nEXPOSE 8080\nCMD [\"java\", \"-jar\", \"app.jar\"]" > Dockerfile
    echo "Criando DockerFile do Java"

    sudo apt install unzip curl
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" unzip awscliv2.zip
    echo "Instalando Curl"

    AWS_ACCESS_KEY_ID="$AWS_ACESS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN" \
    AWS_REGION="us-east-1" \
    aws s3 cp s3://$BUCKET_NAME/techmentor.jar /home/ubuntu/docker-java
    echo "Baixando JAR do S3"

    sudo docker build -t imagem-java .
    sudo docker run -p 8080:8080 --name ContainerJava \
    -v /home/ubuntu/base-dados:/app/base-dados \
    -e AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID' \
    -e AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY' \
    -e AWS_SESSION_TOKEN='$AWS_SESSION_TOKEN' \
    imagem-java
    echo "Criando o Conainer de Java"

    cd ..
    mkdir docker-node
    cd docker-node
    touch Dockerfile
    echo -e "FROM node:latest\n\nWORKDIR /usr/src/app\n\nRUN git clone https://github.com/TechMentorProject/site-institucional.git\n\nWORKDIR /usr/src/app/site-institucional/web-data-viz\n\nRUN npm install\n\nEXPOSE 3030\n\nCMD [\"npm\", \"start\"]" > Dockerfile
    echo "Criando DockerFile do Node"

    sudo docker build -t imagem-node .
    sudo docker run -d --name ContainerNODE -p 3030:3030 imagem-node
    echo "Criando o Container de Node"

    crontab -e
    0 1 * * * /home/ubuntu/docker/rodar_java.sh

    echo "Processo finalizado"
EOF