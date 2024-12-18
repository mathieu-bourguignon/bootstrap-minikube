## Introduction

This project is designed to test the capabilities of a DevOps engineer. The goal is to deploy a simple API that performs random CPU-intensive tasks and improve the stack with monitoring, better deployment strategies using Helm, and implementing autoscaling among other enhancements.

## Prerequisites

- [Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Docker](https://docs.docker.com/get-docker/)
- [Istio](https://istio.io/latest/docs/setup/getting-started/#download)
- [Node.js](https://nodejs.org/) (for Artillery)

## Getting Started

### Step 1: Bootstrap the Stack

All the initialization steps are automated in the `bootstrap.sh` script. Run the script to start Minikube, install Istio, and deploy the test API.

```bash
./bootstrap.sh
```

### Step 2: Access the API
Start the Minikube tunnel to expose the services on localhost:
```
You can now access the API at:

http://localhost/test
http://localhost/hello
```

### Step 3: Load Testing with Artillery
Run the loadtest.sh script to perform a load test on the API using Artillery.

```
./loadtest.sh
```


## Improvements to the Stack
As a DevOps engineer, you are expected to improve the stack in the following ways:

### Monitoring:

- Integrate Prometheus and Grafana for monitoring.
- Set up alerting for critical metrics.

### Helm Deployment:

- Create a Helm chart for deploying the application.
- Add configuration options for easy customization and deployment.

### Autoscaling:

- Fine-tune the Horizontal Pod Autoscaler based on application load.

### Logging:

- Integrate centralized logging using tools like ELK stack (Elasticsearch, Logstash, Kibana) or Loki.

### CI/CD:

- Set up a CI/CD pipeline using tools GitHub Actions.
- Implement automated testing and deployment.

### Security:

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
- Deploying the test API
- Setting up Istio Gateways and VirtualServices



``` 
loadtest.sh
```

This script performs a load test on the API using Artillery.