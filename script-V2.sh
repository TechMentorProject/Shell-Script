#!/bin/bash

BUCKET_NAME="techmentor-bucket"
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
AWS_SESSION_TOKEN=""
IP_EC2_PUBLIC=""
KEY_NAME=".pem"

AWS_BUCKET_ACCESS_KEY_ID=""
AWS_BUCKET_SECRET_ACCESS_KEY=""
AWS_BUCKET_SESSION_TOKEN=""

ssh -i "$KEY_NAME" -o StrictHostKeyChecking=no ubuntu@ec2-$IP_EC2_PUBLIC.compute-1.amazonaws.com << EOF
    sudo apt update && sudo apt upgrade –y

    docker --version
    echo "Instalando ou atualizando Docker"
    sudo apt install docker.io

    sudo rm -r docker-java
    sudo rm -r docker-node

    sudo docker stop $(sudo docker ps -aq)
    sudo docker rm $(sudo docker ps -aq)
    sudo docker rmi -f $(sudo docker images -q)

    sudo systemctl start docker
    sudo systemctl enable docker
    echo "Docker ativado"

    sudo docker pull mysql:5.7
    sudo docker run -d -p 3306:3306 --name ContainerBD -e "MYSQL_DATABASE=techmentor" -e "MYSQL_ROOT_PASSWORD=root" mysql:5.7
    echo "Container de BD criado"

    mkdir docker-java
    cd docker-java

    AWS_ACCESS_KEY_ID="$AWS_BUCKET_ACESS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$AWS_BUCKET_SECRET_ACCESS_KEY" \
    AWS_SESSION_TOKEN="$AWS_BUCKET_SESSION_TOKEN" \
    AWS_REGION="us-east-1" \
    aws s3 cp s3://$BUCKET_NAME/techmentor.jar /home/ubuntu/docker-java
    echo "JAR baixado do S3"
    echo "------------------------------------------"
    ls
    sleep 30

    touch Dockerfile
    echo -e "FROM openjdk:21-jdk\nWORKDIR /app\nCOPY techmentor.jar app.jar\nEXPOSE 8080\nCMD [\"java\", \"-jar\", \"app.jar\"]" > Dockerfile
    echo "Criando DockerFile do Java"

    sudo apt install unzip curl -y
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" unzip awscliv2.zip
    echo "Instalando Curl instalado"

    pwd
    sudo docker images
    echo "===================================================================================================="
    ls
    echo "===================================================================================================="
    sleep 20
    sudo docker build -t imagem-java .
    sudo docker images
    sleep 20
    echo "===================================================================================================="
    sudo docker run -p 8080:8080 --name ContainerJava \
    -v /home/ubuntu/docker-java:/app \
    -e AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID' \
    -e AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY' \
    -e AWS_SESSION_TOKEN='$AWS_SESSION_TOKEN' \
    imagem-java
    echo "Container de Java criado"

    cd ..
    mkdir docker-node
    cd docker-node
    touch Dockerfile
    echo -e "FROM node:latest\n\nWORKDIR /usr/src/app\n\nRUN git clone https://github.com/TechMentorProject/site-institucional.git\n\nWORKDIR /usr/src/app/site-institucional/web-data-viz\n\nRUN npm install\n\nEXPOSE 3030\n\nCMD [\"npm\", \"start\"]" > Dockerfile
    echo "DockerFile do Node criado"

    sudo docker build -t imagem-node .
    sudo docker run -d --name ContainerNODE -p 3030:3030 imagem-node
    echo "Container de Node criado"

    crontab -l; echo "0 1 * * * /home/ubuntu/docker/rodar_java.sh"
    sleep 20

    echo "Processo finalizado"

    sleep 120
EOF