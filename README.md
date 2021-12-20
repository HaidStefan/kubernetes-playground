# kubernetes-playground

Run container with Docker
    
    docker run -p 5678:5678 localhost:5000/echo-service:1.0.2 -text=test


Deploy in Cluster

    kubectl apply -f manifests/config.yaml