#!/bin/bash
set -x
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 30000
    hostPort: 80
    listenAddress: "127.0.0.1"
    protocol: TCP
  - containerPort: 30001
    hostPort: 443
    listenAddress: "127.0.0.1"
    protocol: TCP
  - containerPort: 30002
    hostPort: 15021
    listenAddress: "127.0.0.1"
    protocol: TCP
EOF

echo "calico for k8s NetworkPolicy fun"
curl https://docs.projectcalico.org/manifests/calico.yaml | kubectl apply -f -

# assuming istio handles this? IT seems it does enforce 
#echo "Applying policy - deny all ingress traffic"
#kubectl apply -f - <<EOF
#---
#apiVersion: networking.k8s.io/v1
#kind: NetworkPolicy
#metadata:
#  name: default-deny-ingress
#spec:
#  podSelector: {}
#  policyTypes:
#  - Ingress
#EOF
# i dont understand where the verb "deny" is here...


istioctl operator init

kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  namespace: istio-system
  name: istiocontrolplane
spec:
  components:
    base:
      enabled: true
    cni:
      enabled: true
    ingressGateways:
      - enabled: true
        name: istio-ingressgateway
        k8s:
          hpaSpec:
            maxReplicas: 1
          nodeSelector:
            ingress-ready: "true"
          service:
            type: NodePort
          overlays:
            - apiVersion: v1
              kind: Service
              name: istio-ingressgateway
              patches:
                - path: spec.ports
                  value:
                    - name: status-port
                      port: 15021
                      targetPort: 15021
                      nodePort: 30002
                      protocol: TCP
                    - name: http2
                      port: 80
                      targetPort: 8080
                      nodePort: 30000
                      protocol: TCP
                    - name: https
                      port: 443
                      targetPort: 8443
                      nodePort: 30001
                      protocol: TCP
            - apiVersion: policy/v1beta1
              kind: PodDisruptionBudget
              name: istio-ingressgateway
              patches:
                - path: spec.minAvailable
                  value: 0
    pilot:
      enabled: true
      k8s:
        hpaSpec:
          maxReplicas: 1
        overlays:
          - apiVersion: policy/v1beta1
            kind: PodDisruptionBudget
            name: istiod
            patches:
              - path: spec.minAvailable
                value: 0
  meshConfig:
    accessLogFile: "/dev/stdout"
    accessLogEncoding: "JSON"
  values:
    global:
    cni:
      excludeNamespaces:
        - istio-system
        - kube-system
    sidecarInjectorWebhook:
      rewriteAppHTTPProbe: true

EOF

# https://www.google.com/search?q=autobots+roll+out+meme&client=firefox-b-d&biw=1024&bih=1056&tbm=vid&sxsrf=AOaemvL8JNKPOsREHdFrv42cLjS9lcjsmA%3A1634152566673&ei=djBnYcuwKOD_7_UP3rm42As&oq=autobots+roll+out+meme&gs_l=psy-ab-video.3..35i39k1j0i512k1j0i22i30k1l3.547.1892.0.3351.5.5.0.0.0.0.174.336.0j2.2.0....0...1c.1.64.psy-ab-video..3.2.335...0i512i263i20k1.0.4rNjFNXSij4
kubectl label namespace default istio-injection=enabled

# The Istio operator controller begins the process of installing Istio within 90 seconds of the creation of the IstioOperator resource. The Istio installation completes within 120 seconds.
# wut and how can you even?
while kubectl get pods -n istio-system -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' | grep False
do
kubectl get pods -n istio-system
echo 'waiting for istio pods...'
sleep 3
done
-----snip----

versuch Blue/Green:

---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: app-gateway
spec:
  selector:
    istio: ingressgateway
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - "*"
  gateways:
  - app-gateway
  http:
    - route:
      - destination:
          host: myapp
          subset: v1
        weight: 50 
      - destination:
          host: myapp
          subset: v2
        weight: 50
      #- destination:
      #    host: myapp
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: myapp-destination-rule
spec:
  host: myapp
  trafficPolicy:
    loadBalancer:
      consistentHash:
        useSourceIp: true
        #httpQueryParameterName: hashable
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
---
apiVersion: v1
kind: Service
metadata:
  name: myapp
  labels:
    app: myapp
spec:
  selector:
    app: myapp
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80 
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      version: v1
  template:
    metadata:
      labels:
        app: myapp
        version: v1
    spec:
      containers:
      - name: myapp
        image: hashicorp/http-echo:0.2.1
        args:
          - "-text=youronV1"
          - "-listen=:80"
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-v2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
      version: v2
  template:
    metadata:
      labels:
        app: myapp
        version: v2
    spec:
      containers:
      - name: myapp
        image: hashicorp/http-echo:latest
        args:
        - "-text=youronV2"
        - "-listen=:80"
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
