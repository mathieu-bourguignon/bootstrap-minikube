# Load Test Results - Python API

## Test Configuration
- **Tool**: Artillery
- **Target**: http://localhost/test (via Istio Gateway)
- **Duration**: 2 minutes 29 s

## Summary Results
- **Total Requests**: 900
- **Successful (200)**: 217 
- **Server Errors (500)**: 28 
- **Service Unavailable (503)**: 655 
- **Success Rate**: 24.1%

## Response Times
- **Min**: -117ms (negative due to clock sync)
- **Max**: 5893ms
- **Mean**: 555.2ms
- **Median**: 82.3ms
- **P95**: 2416.8ms
- **P99**: 3984.7ms

## HPA Behavior
- **Initial Replicas**: 1 (v1) + 1 (v2)
- **Max Replicas Reached**: 5 (v1) + 2 (v2)
- **Scale-up Triggered**: Yes
- **Target CPU Utilization**: 50%

## Critical Issues Identified

### 1. High 503 Error Rate (72.8%)
**Root Cause**: New pods fail to become ready quickly enough

**Evidence**: 
Pods remain stuck in initialization phase while HPA continues scaling.

### 2. Pod Initialization Bottleneck
**Root Causes**:
- Istio sidecar injection takes time
- Postgres/Redis connection establishment
- Readiness probes too aggressive (5s initial delay)
- Database seeding on startup

### 3. Slow Response Times Under Load
- P95 latency: 2416.8ms (target should be <500ms)
- P99 latency: 3984.7ms (target should be <1000ms)
- CPU-intensive `/` endpoint with random delays (20ms-2s)

## Recommendations

### Immediate Fixes
1. **Increase probe timeouts**:
   ```yaml
   readinessProbe:
     initialDelaySeconds: 20  # was 5
     timeoutSeconds: 5
     failureThreshold: 3
   
   livenessProbe:
     initialDelaySeconds: 30  # was 10
     timeoutSeconds: 5
  ```
2. **Add startup probe for slow initialization**:
   ```yaml
    startupProbe:
    httpGet:
        path: /health
        port: 5000
    initialDelaySeconds: 0
    periodSeconds: 10
    failureThreshold: 30  # 5 mi to start
  ```
## Dashboards Grafana
- Python API : http://localhost/grafana/d/python-api-observability
- Vue globale : http://localhost/grafana/d/observability-overview
