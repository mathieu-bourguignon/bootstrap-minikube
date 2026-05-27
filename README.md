## Introduction

This project is designed to test the capabilities of a DevOps engineer. The goal is to deploy a simple API that performs random CPU-intensive tasks and improve the stack with monitoring, GitOps deployment with Argo CD, better deployment strategies using Helm, and implementing autoscaling among other enhancements.

## Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Docker](https://docs.docker.com/get-docker/)
- [Istio](https://istio.io/latest/docs/setup/getting-started/#download)
- [Node.js](https://nodejs.org/) (for Artillery)

## GitOps Layout

Argo CD deploys the application manifests from this repository:

- `apps/hello-minikube`: echo server deployment and service.
- `apps/python-api`: Helm chart for the Python API, including canary subsets, HPA, probes, resources, and Prometheus scraping annotations.
- `apps/platform-routing`: shared Istio Gateway and single VirtualService for `/hello`, `/test`, `/grafana`, `/kiali`, and `/argocd`.
- `argocd/applications`: Argo CD `Application` resources for the apps and platform routing.
- `monitoring`: Loki, Promtail, Tempo, Alertmanager, dashboards, and Prometheus alert rules.

The Argo CD applications target the `argocd` branch. Push this branch before running the bootstrap if Argo CD needs to pull the latest manifests from GitHub.

## Getting Started

### Step 1: Bootstrap the Stack

All the initialization steps are automated in the `bootstrap.sh` script. Run the script to start Minikube, install Istio, install Argo CD, build the local API image, and register the Argo CD applications.

```bash
./bootstrap.sh
```

### Step 2: Access the API
Start the Minikube tunnel to expose the services on localhost:
```
You can now access the API at:

http://localhost/test
http://localhost/hello
http://localhost/grafana
http://localhost/kiali
http://localhost/argocd
```

The Python API exposes operational endpoints through the `/test` prefix:

```bash
curl http://localhost/test/health
curl http://localhost/test/ready
curl http://localhost/test/metrics
curl http://localhost/test/data
```

The `/test/data` route initializes a small Postgres schema, fills it with random
POC data when needed, returns one random row, and increments a Redis counter.
Postgres and Redis are deployed by the same `apps/python-api` Helm chart and
synced by the existing `python-api` Argo CD application.

The `/test` route is split 90/10 between `v1` and `v2` by Istio. Repeated calls show which version handled the request:

```bash
for i in {1..20}; do curl -s http://localhost/test; echo; done
```

Get the initial Argo CD admin password with:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 3: Load Testing with Artillery
Run the loadtest.sh script to perform a load test on the API using Artillery.

```
./loadtest.sh
```

### Apply API Changes Without Reinstalling the Cluster

When Minikube, Istio, and Argo CD are already installed, apply only the Python
API stack changes with:

```bash
./apply-python-api-stack.sh
```

The script rebuilds the local `test-api:latest` image inside Minikube, applies
the `apps/python-api` Helm chart locally, restarts the API deployments, and waits
for Postgres, Redis, and the API pods to become ready.

Because Argo CD reads from the remote `argocd` branch, push that branch when you
want GitOps reconciliation to keep exactly the same state over time. By default,
the script pauses auto-sync for the `python-api` Argo CD application so Argo CD
does not immediately revert your local manifests. Re-enable it after pushing:

```bash
kubectl apply -f argocd/applications/python-api.application.yaml
```

Watch autoscaling and canary traffic with:

```bash
kubectl get hpa
kubectl get pods -l app=test-api
kubectl -n istio-system port-forward svc/prometheus 9090:9090
```

Grafana includes a provisioned `Python API Observability` dashboard in the `python-api` folder:

```text
http://localhost/grafana/d/python-api-observability/python-api-observability
```

It combines application metrics from `/metrics`, Istio traffic metrics, and pod-level CPU, memory, and scrape health.

Grafana also includes an `Observability Overview` dashboard in the `observability` folder:

```text
http://localhost/grafana/d/observability-overview/observability-overview
```

This dashboard uses:

- Prometheus for application, mesh, infrastructure, and alert metrics.
- Loki and Promtail for Kubernetes pod logs.
- Tempo as the trace backend for Istio traces.
- Alertmanager plus Prometheus alert rules for Python API health, errors, latency, CPU, and memory.

Useful checks:

```bash
kubectl -n istio-system get pods -l app=loki
kubectl -n istio-system get pods -l app=tempo
kubectl -n istio-system get pods -l app=alertmanager
kubectl -n istio-system get daemonset promtail
kubectl -n istio-system port-forward svc/prometheus 9090:9090
```

In Grafana Explore, use the `Loki` datasource for logs and the `Tempo` datasource for traces.


## Improvements to the Stack
As a DevOps engineer, you are expected to improve the stack in the following ways:

1. Monitoring:

- Integrate Prometheus and Grafana for monitoring.
- Set up alerting for critical metrics.
2. Helm Deployment:

- Create a Helm chart for deploying the application.
- Add configuration options for easy customization and deployment.

3. Autoscaling:

- Fine-tune the Horizontal Pod Autoscaler based on application load.
4. Logging:

- Integrate centralized logging using tools like ELK stack (Elasticsearch, Logstash, Kibana) or Loki.

5. CI/CD:

- Set up a CI/CD pipeline using tools like Jenkins, GitHub Actions, or GitLab CI.
- Implement automated testing and deployment.

6. Security:

- Implement security best practices for Kubernetes (e.g., Network Policies, RBAC).
- Set up vulnerability scanning for container images.

## Conclusion
This project serves as a foundational setup for testing your DevOps skills. Enhance the stack by following best practices and integrating additional tools and technologies to demonstrate your proficiency as a DevOps engineer.

## Scripts
``` 
bootstrap.sh
```
This script initializes the entire stack, including:

- Starting Minikube
- Enabling necessary Minikube addons
- Installing Istio
- Installing Argo CD
- Building the local test API image
- Registering the Argo CD applications for `hello-minikube` and `python-api`
- Setting up Istio Gateways and VirtualServices for monitoring



``` 
loadtest.sh
```

This script performs a load test on the API using Artillery.
