#!/bin/bash


MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-minikube}"
KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-${MINIKUBE_PROFILE}}"

kubectl_minikube() {
  kubectl --context "${KUBECTL_CONTEXT}" "$@"
}

curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64

minikube -p "${MINIKUBE_PROFILE}" delete
# Install 
# minikube dashboard
# Start Minikube
minikube -p "${MINIKUBE_PROFILE}" start --driver=docker --force
minikube -p "${MINIKUBE_PROFILE}" update-context
kubectl config use-context "${KUBECTL_CONTEXT}"

# Enable Ingress
minikube -p "${MINIKUBE_PROFILE}" addons enable ingress
minikube -p "${MINIKUBE_PROFILE}" addons enable metrics-server

# Install Istio
ISTIO_VERSION=1.29.2
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
cd istio-$ISTIO_VERSION
export PATH=$PWD/bin:$PATH
cd ..

# Install Istio
istioctl install \
  --context "${KUBECTL_CONTEXT}" \
  --set profile=demo \
  --set meshConfig.enableTracing=true \
  --set meshConfig.extensionProviders[0].name=tempo \
  --set meshConfig.extensionProviders[0].zipkin.service=tempo.istio-system.svc.cluster.local \
  --set meshConfig.extensionProviders[0].zipkin.port=9411 \
  -y

# Label the default namespace to enable Istio sidecar injection
kubectl_minikube label namespace default istio-injection=enabled --overwrite

# Install Kiali
kubectl_minikube apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/kiali.yaml
kubectl_minikube apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/prometheus.yaml
kubectl_minikube apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/addons/grafana.yaml
kubectl_minikube -n istio-system patch configmap kiali --type merge --patch-file monitoring/kiali-grafana-patch.yaml
kubectl_minikube apply -f monitoring/alertmanager.yaml
kubectl_minikube apply -f monitoring/loki.yaml
kubectl_minikube apply -f monitoring/tempo.yaml
kubectl_minikube -n istio-system rollout status deployment/alertmanager --timeout=300s
kubectl_minikube -n istio-system rollout status deployment/loki --timeout=300s
kubectl_minikube -n istio-system rollout status daemonset/promtail --timeout=300s
kubectl_minikube -n istio-system rollout status deployment/tempo --timeout=300s
kubectl_minikube -n istio-system patch configmap prometheus --type merge --patch-file monitoring/prometheus-alert-rules-patch.yaml
kubectl_minikube -n istio-system set env deployment/grafana GF_SERVER_ROOT_URL=http://localhost/grafana/ GF_SERVER_SERVE_FROM_SUB_PATH=true
kubectl_minikube apply -f monitoring/grafana-python-api-dashboard.yaml
kubectl_minikube apply -f monitoring/grafana-observability-dashboard.yaml
kubectl_minikube -n istio-system patch configmap grafana --type merge --patch-file monitoring/grafana-provider-patch.yaml
kubectl_minikube -n istio-system patch configmap grafana --type merge --patch-file monitoring/grafana-datasources-patch.yaml
kubectl_minikube -n istio-system patch deployment grafana --type strategic --patch-file monitoring/grafana-deployment-dashboard-patch.yaml
kubectl_minikube -n istio-system rollout restart deployment/prometheus
kubectl_minikube -n istio-system rollout status deployment/prometheus --timeout=300s
kubectl_minikube -n istio-system rollout restart deployment/grafana
kubectl_minikube -n istio-system rollout status deployment/grafana --timeout=300s
kubectl_minikube apply -f apps/platform-routing/gateway.yaml

# Install Argo CD
kubectl_minikube create namespace argocd --dry-run=client -o yaml | kubectl_minikube apply -f -
kubectl_minikube label namespace argocd istio-injection=enabled --overwrite
kubectl_minikube apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl_minikube wait --for condition=established --timeout=60s crd/applications.argoproj.io
kubectl_minikube wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
kubectl_minikube -n argocd patch deployment argocd-server --type json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/args","value":["/usr/local/bin/argocd-server","--insecure","--rootpath=/argocd","--basehref=/argocd/"]}]'
kubectl_minikube -n argocd patch configmap argocd-cm --type merge -p '{"data":{"url":"http://localhost/argocd"}}'
kubectl_minikube wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

cd python-api

eval "$(minikube -p "${MINIKUBE_PROFILE}" docker-env)"
docker build -t test-api .

cd ..

kubectl_minikube apply -f argocd/applications/
kubectl_minikube delete gateway grafana-gateway kiali-gateway argocd-gateway hello-minikube-gateway test-api-gateway --ignore-not-found
kubectl_minikube delete virtualservice grafana kiali argocd hello-minikube test-api --ignore-not-found

# Install artillery
nvm use 22
npm install -g artillery

# Get the URL for the Istio Ingress Gateway
export INGRESS_HOST=localhost
export GATEWAY_URL=$INGRESS_HOST

echo "Access your hello-minikube service at http://localhost/hello"
echo "Access the Grafana dashboard at http://localhost/grafana"
echo "Access the observability dashboard at http://localhost/grafana/d/observability-overview/observability-overview"
echo "Access the Kiali dashboard at http://localhost/kiali"
echo "Access the Argo CD UI at http://localhost/argocd"
echo "Access the minikube dashboard using 'minikube dashboard'"
echo "Argo CD UI admin password:"
kubectl_minikube -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Start minikube tunnel to expose services on localhost
minikube -p "${MINIKUBE_PROFILE}" tunnel
