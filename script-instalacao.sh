#!/bin/bash

BUCKET_NAME=""

AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
AWS_SESSION_TOKEN=""

IP_EC2_PUBLIC=""
KEY_NAME=""


ssh -i "$KEY_NAME" -o StrictHostKeyChecking=no ubuntu@ec2-$IP_EC2_PUBLIC.compute-1.amazonaws.com << EOF
    echo "Atualização dos packages"
    sudo apt update && sudo apt upgrade -y
    sudo rm awscliv2.zip
    sudo rm -r aws

    echo "Instalando dependências"
    sudo apt install unzip curl -y
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    chmod +x aws/install
    sudo ./aws/install
    echo "AWS CLI instalado"
    sleep 15

    echo "Instalando / Atualizando Docker"
    sudo apt install docker.io -y
    sleep 15

    echo "Excluindo diretórios"
    sudo rm -rf docker-java docker-node

    sudo docker stop \$(sudo docker ps -aq)
    sudo docker rm \$(sudo docker ps -aq)
    sudo docker rmi -f \$(sudo docker images -q)
    echo "Limpeza de containers e images finalizada"
    sleep 15

    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker ativado"

    sudo docker pull mysql:5.7
    sudo docker run -d -p 3306:3306 --name ContainerBD -e "MYSQL_DATABASE=techmentor" -e "MYSQL_ROOT_PASSWORD=root" mysql:5.7
    echo "Container de BD criado"
    sleep 15

    echo "Criação de diretório Java"
    mkdir docker-java
    cd docker-java

    echo "Baixando o JAR do S3"
    AWS_ACCESS_KEY_ID="$AWS_BUCKET_ACESS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$AWS_BUCKET_SECRET_ACCESS_KEY" \
    AWS_SESSION_TOKEN="$AWS_BUCKET_SESSION_TOKEN" \
    AWS_REGION="us-east-1" \
    aws s3 cp s3://$BUCKET_NAME/techmentor.jar /home/ubuntu/docker-java
    echo "JAR baixado do S3"

    ls /home/ubuntu/docker-java
    sleep 15

    echo -e "FROM openjdk:21-jdk\nWORKDIR /app\nCOPY techmentor.jar /app/techmentor.jar\nEXPOSE 8080\nCMD [\"java\", \"-jar\", \"/app/techmentor.jar\"]" > Dockerfile
    echo "DockerFile do Java criado"

    sudo docker build -t imagem-java .
    
    sudo docker run -p 8080:8080 --name ContainerJava \
        -v /home/ubuntu/docker-java:/app \
        -e AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID' \
        -e AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY' \
        -e AWS_SESSION_TOKEN='$AWS_SESSION_TOKEN' \
        imagem-java
    echo "Container de Java criado"
    sleep 15

    echo "Criação de diretório Node"
    cd ..
    mkdir docker-node
    cd docker-node

    ls
    sleep 15

    echo -e "FROM node:latest\n\nWORKDIR /usr/src/app\n\nRUN git clone https://github.com/TechMentorProject/site-institucional.git\n\nWORKDIR /usr/src/app/site-institucional/web-data-viz\n\nRUN npm install\n\nEXPOSE 3030\n\nCMD [\"npm\", \"start\"]" > Dockerfile
    echo "DockerFile do Node criado"

    sudo docker build -t imagem-node .
    sudo docker run -d --name ContainerNODE -p 3030:3030 imagem-node
    echo "Container de Node criado"

    (crontab -l 2>/dev/null; echo "0 1 * * * /home/ubuntu/docker/rodar_java.sh") | crontab -
    echo "Processo finalizado"

    sleep 500
EOF