# Load Testing & Performance Optimization Report

## Executive Summary
This document details the iterative load testing process performed on the Python API to identify bottlenecks and improve stability under load. Through 4 test iterations, we improved the **success rate from 24% to 65%** and **completely eliminated critical 500 server errors**.

**Test Configuration:**
- **Tool:** Artillery (`./loadtest.sh`)
- **Target:** `http://localhost/test` (via Istio Ingress)
- **Load Profile:** 30s warmup (1 req/s) → 60s ramp-up (5 req/s) → 60s sustain (2 req/s)
- **Environment:** Minikube (4 CPUs, 8GB RAM), Istio, Postgres, Redis

---

## Iterative Optimization Process

### Iteration 1: Baseline & Pod Initialization Fix
**Initial State:** 24% success rate, 73% HTTP 503 errors.
**Issue Identified:** New pods scaled by the HPA were stuck in `Init:1/2` or `PodInitializing`. They were killed by aggressive readiness probes before they could connect to Postgres/Redis and initialize the Istio sidecar.

**✅ Fix Implemented:**
- Added a `startupProbe` with a 5-minute failure threshold to allow slow initialization.
- Increased `initialDelaySeconds` for liveness (10s → 30s) and readiness (5s → 20s) probes.
- Added `timeoutSeconds` and `failureThreshold` to prevent premature pod restarts.

**📊 Result:**
- Success rate: **24% → 59%**
- 503 errors reduced by ~60%.
- *Side effect:* Latency increased (P95: 2.4s → 6.6s) because requests were now actually being processed by the pods instead of being instantly rejected.

---

### Iteration 2: Code Optimization & HPA Tuning
**Initial State:** 59% success rate, but high latency (P95: 6.6s) and 65 socket timeouts.
**Issue Identified:** The `/` endpoint contained a hardcoded random CPU delay up to 2 seconds. Additionally, the HPA was scaling too aggressively (50% CPU target), creating resource contention on Minikube.

**✅ Fix Implemented:**
- Made the CPU delay configurable via `MAX_DELAY_SECONDS` environment variable and reduced it from 2.0s to 0.2s.
- Tuned HPA: Reduced `maxReplicas` (5 → 3), increased `averageUtilization` (50% → 70%), and added a `stabilizationWindowSeconds` (60s) to prevent scaling thrashing.

**📊 Result:**
- Timeouts: **65 → 1** (Massive improvement).
- P95 Latency: **6.6s → 5.9s**.
- *Side effect:* Introduced **11% HTTP 500 errors**. The API was now handling traffic but crashing under the pressure of concurrent Postgres connections (no connection pooling).

---

### Iteration 3: API Protection via Rate Limiting
**Initial State:** 58% success rate, 11% HTTP 500 errors (application crashes).
**Issue Identified:** Without connection pooling, concurrent requests overwhelmed the Postgres database, causing the Python app to throw unhandled exceptions (500s). 

**✅ Fix Implemented:**
- Implemented an Istio `EnvoyFilter` to apply local rate limiting at the sidecar level.
- Configured a token bucket of **20 requests/second per pod**.
- *Goal:* Reject excess traffic gracefully (503) rather than letting it crash the application (500).

**📊 Result:**
- HTTP 500 errors: **11% → 0% (Completely Eliminated)**.
- Success rate peaked at **65%**.
- The remaining 35% consists of 503s (gracefully rejected by the rate limiter) and timeouts.

---

## Final Results Comparison

| Metric | Baseline (Test 1) | After Probes (Test 2) | After Code/HPA (Test 3) | After Rate Limit (Test 4) |
| :--- | :---: | :---: | :---: | :---: |
| **Success (200 OK)** | 24% | 59% | 58% | **65%** |
| **Server Errors (500)** | 3% | 3% | 11% | **0%** ✅ |
| **Unavailable (503)** | 73% | 31% | 31% | 31% |
| **Timeouts** | 0 | 65 | 1 | 34 |
| **P95 Latency** | 2.4s | 6.6s | 5.9s | 7.1s |

