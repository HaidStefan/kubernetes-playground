Build and Push Image to registry

    docker build --tag localhost:5000/echo-service:1.0.2 .
    docker push localhost:5000/echo-service:1.0.2