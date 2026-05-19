#!/bin/bash

curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

minikube delete
# Install 
# minikube dashboard
# Start Minikube
minikube start --driver=docker --force

# Enable Ingress
minikube addons enable ingress
minikube addons enable metrics-server

# Install Istio
ISTIO_VERSION=1.29.2
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
cd istio-$ISTIO_VERSION
export PATH=$PWD/bin:$PATH
cd ..

# Install Istio 
istioctl install --set profile=demo -y

# Label the default namespace to enable Istio sidecar injection
kubectl label namespace default istio-injection=enabled

# Install Kiali
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/kiali.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/jaeger.yaml
kubectl -n istio-system set env deployment/grafana GF_SERVER_ROOT_URL=http://localhost/grafana/ GF_SERVER_SERVE_FROM_SUB_PATH=true
kubectl apply -f monitoring/grafana-python-api-dashboard.yaml
kubectl -n istio-system patch configmap grafana --type merge --patch-file monitoring/grafana-provider-patch.yaml
kubectl -n istio-system patch deployment grafana --type strategic --patch-file monitoring/grafana-deployment-dashboard-patch.yaml
kubectl -n istio-system rollout restart deployment/grafana
kubectl -n istio-system rollout status deployment/grafana --timeout=300s
kubectl apply -f monitoring/grafana.gateway.yaml
kubectl apply -f monitoring/kiali.gateway.yaml

# Install Argo CD
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for condition=established --timeout=60s crd/applications.argoproj.io
kubectl wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl -n argocd patch deployment argocd-server --type json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["/usr/local/bin/argocd-server","--insecure","--rootpath=/argocd","--basehref=/argocd/"]}]'
kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"url":"http://localhost/argocd"}}'
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
kubectl apply -f monitoring/argocd.gateway.yaml

cd python-api

eval $(minikube -p minikube docker-env)
docker build -t test-api .

cd ..

kubectl apply -f argocd/applications/

# Install artillery
nvm use 22
npm install -g artillery

# Get the URL for the Istio Ingress Gateway
export INGRESS_HOST=localhost
export GATEWAY_URL=$INGRESS_HOST

echo "Access your hello-minikube service at http://localhost/hello"
echo "Access the Grafana dashboard at http://localhost/grafana"
echo "Access the Kiali dashboard at http://localhost/kiali"
echo "Access the Argo CD UI at http://localhost/argocd"
echo "Access the minikube dashboard using 'minikube dashboard'"
echo "Argo CD UI admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Start minikube tunnel to expose services on localhost
minikube tunnel
