#!/bin/bash

cd helm-chart

# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update


# Create monitoring and logging namespace
kubectl create namespace monitoring || true
kubectl create namespace logging || true

# Install CRDs
#kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.67.8/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
#kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.67.8/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml
#kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.67.8/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
#kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.67.8/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
#kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.67.8/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml

# Update dependencies
helm dependency update prometheus/
helm dependency update grafana/
helm dependency update loki/

helm upgrade --install prometheus ./prometheus \
  --namespace monitoring \
  --wait

helm upgrade --install grafana ./grafana \
  --namespace monitoring \
  --wait

helm upgrade --install loki ./loki \
  --namespace logging \
  --wait

helm upgrade --install python-api ./python-api \
  --namespace default \
  --wait
