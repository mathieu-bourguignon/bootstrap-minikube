#!/bin/bash

minikube delete
# Install 
# minikube dashboard
# Start Minikube
minikube start --driver=docker --force

# Enable Ingress
minikube addons enable ingress
minikube addons enable metrics-server

# Install Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.1 sh -
cd istio-1.24.1
export PATH=$PWD/bin:$PATH
cd ..

# Install Istio 
istioctl install --set profile=demo -y

# Label the default namespace to enable Istio sidecar injection
kubectl label namespace default istio-injection=enabled

# Deploy a sample application (hello-minikube)
kubectl create deployment hello-minikube --image=kicbase/echo-server:1.0
kubectl expose deployment hello-minikube --port=8080

# Create a Gateway and VirtualService for hello-minikube
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: hello-minikube-gateway
spec:
  selector:
    istio: ingressgateway # use istio default controller
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*"
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: hello-minikube
spec:
  hosts:
  - "*"
  gateways:
  - hello-minikube-gateway
  http:
  - match:
    - uri:
        prefix: /hello
    rewrite:
      uri: /
    route:
    - destination:
        host: hello-minikube
        port:
          number: 8080
EOF

# Install Kiali
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.24/samples/addons/jaeger.yaml

cd python-api

eval $(minikube -p minikube docker-env)
docker build -t test-api .

kubectl apply -f python-api.deployment.yaml
kubectl apply -f python-api.gateway.yaml

cd ..


# Install artillery
npm install -g artillery

# Get the URL for the Istio Ingress Gateway
export INGRESS_HOST=localhost
export GATEWAY_URL=$INGRESS_HOST

echo "Access your hello-minikube service at http://localhost/hello"
echo "Access the Grafana dashboard at http://localhost/grafana"
echo "Access the Kiali dashboard using 'kubectl port-forward service/kiali 20001:20001 -n istio-system'"
echo "Access the minikube dashboard using 'minikube dashboard'"


# Start minikube tunnel to expose services on localhost
minikube tunnel 