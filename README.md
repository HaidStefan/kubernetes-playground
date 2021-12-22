# kubernetes-playground

Run container with Docker
    
    docker run -p 5678:5678 localhost:5000/echo-service:1.0.2 -text=test

Deploy in Cluster

    kubectl apply -f manifests/config.yaml

Add Prometheus and Kiali

    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.12/samples/addons/prometheus.yaml
    kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.12/samples/addons/kiali.yaml

Open Dashboard

    istioctl dashboard kiali

Delete all resources of default namespace and all virtual services

    kubectl delete all --all -n default
    kubectl delete virtualservice --all
    kubectl delete peerauthentication default

Curl with Cookie

    curl --cookie "node=blue" localhost:80