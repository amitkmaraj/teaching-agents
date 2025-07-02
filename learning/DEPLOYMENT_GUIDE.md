# Teaching Agents - Deployment Guide

## Overview

This guide covers deploying the Teaching Agents system in various environments, from local development to production cloud deployments.

## Table of Contents

1. [Local Development Setup](#local-development-setup)
2. [Docker Deployment](#docker-deployment)
3. [Google Cloud Run Deployment](#google-cloud-run-deployment)
4. [Kubernetes Deployment](#kubernetes-deployment)
5. [Environment Configuration](#environment-configuration)
6. [Monitoring and Logging](#monitoring-and-logging)
7. [Security Considerations](#security-considerations)

## Local Development Setup

### Prerequisites

- Python 3.12+
- Google Cloud SDK
- uv package manager
- Git

### Step 1: Environment Setup

```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Clone repository
git clone <repository-url>
cd teaching-agents

# Install Python and dependencies
uv python install 3.12
uv sync --frozen
```

### Step 2: Google Cloud Authentication

```bash
# Authenticate with Google Cloud
gcloud auth application-default login

# Set project ID
export GOOGLE_CLOUD_PROJECT=your-project-id

# Enable required APIs
gcloud services enable aiplatform.googleapis.com
```

### Step 3: Environment Files

Create environment files for each component:

**Scholar Agent** (`.env` in `remote_agents/scholar_agent/`):

```env
API_KEY=dev_api_key_123
GCLOUD_LOCATION=us-central1
GCLOUD_PROJECT_ID=your-project-id
PORT=10000
```

**Teacher Agent** (`.env` in `remote_agents/teacher_agent/`):

```env
API_KEY=dev_api_key_123
GCLOUD_LOCATION=us-central1
GCLOUD_PROJECT_ID=your-project-id
PORT=10001
```

**Researcher Agent** (`.env` in `researcher/`):

```env
SCHOLAR_AGENT_AUTH=dev_api_key_123
SCHOLAR_AGENT_URL=http://localhost:10000
TEACHER_AGENT_AUTH=dev_api_key_123
TEACHER_AGENT_URL=http://localhost:10001
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=us-central1
```

### Step 4: Running the System

Start each agent in separate terminals:

**Terminal 1 - Scholar Agent:**

```bash
cd remote_agents/scholar_agent
uv run .
```

**Terminal 2 - Teacher Agent:**

```bash
cd remote_agents/teacher_agent
uv run .
```

**Terminal 3 - Researcher Agent:**

```bash
uv run researcher_demo.py
```

### Step 5: Health Checks

Verify all agents are running:

```bash
# Check Scholar Agent
curl http://localhost:10000/.well-known/agent

# Check Teacher Agent
curl http://localhost:10001/.well-known/agent

# Check Researcher Interface
curl http://localhost:8080
```

## Docker Deployment

### Building Images

Each agent has its own Dockerfile for containerization.

#### Scholar Agent Docker Build

```bash
cd remote_agents/scholar_agent
docker build -t scholar-agent:latest .
```

#### Teacher Agent Docker Build

```bash
cd remote_agents/teacher_agent
docker build -t teacher-agent:latest .
```

#### Researcher Agent Docker Build

Create `Dockerfile` in root directory:

```dockerfile
FROM python:3.12-slim

WORKDIR /app

# Install uv
RUN pip install uv

# Copy dependency files
COPY pyproject.toml uv.lock ./

# Install dependencies
RUN uv sync --frozen --no-dev

# Copy application code
COPY . .

# Expose port
EXPOSE 8080

# Run application
CMD ["uv", "run", "researcher_demo.py"]
```

Build the image:

```bash
docker build -t researcher-agent:latest .
```

### Docker Compose Setup

Create `docker-compose.yml`:

```yaml
version: "3.8"

services:
  scholar-agent:
    build: ./remote_agents/scholar_agent
    ports:
      - "10000:10000"
    environment:
      - API_KEY=docker_api_key_123
      - GCLOUD_LOCATION=us-central1
      - GCLOUD_PROJECT_ID=${GOOGLE_CLOUD_PROJECT}
      - PORT=10000
    volumes:
      - ~/.config/gcloud:/root/.config/gcloud:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:10000/.well-known/agent"]
      interval: 30s
      timeout: 10s
      retries: 3

  teacher-agent:
    build: ./remote_agents/teacher_agent
    ports:
      - "10001:10001"
    environment:
      - API_KEY=docker_api_key_123
      - GCLOUD_LOCATION=us-central1
      - GCLOUD_PROJECT_ID=${GOOGLE_CLOUD_PROJECT}
      - PORT=10001
    volumes:
      - ~/.config/gcloud:/root/.config/gcloud:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:10001/.well-known/agent"]
      interval: 30s
      timeout: 10s
      retries: 3

  researcher-agent:
    build: .
    ports:
      - "8080:8080"
    environment:
      - SCHOLAR_AGENT_AUTH=docker_api_key_123
      - SCHOLAR_AGENT_URL=http://scholar-agent:10000
      - TEACHER_AGENT_AUTH=docker_api_key_123
      - TEACHER_AGENT_URL=http://teacher-agent:10001
      - GOOGLE_GENAI_USE_VERTEXAI=TRUE
      - GOOGLE_CLOUD_PROJECT=${GOOGLE_CLOUD_PROJECT}
      - GOOGLE_CLOUD_LOCATION=us-central1
    depends_on:
      - scholar-agent
      - teacher-agent
    volumes:
      - ~/.config/gcloud:/root/.config/gcloud:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  default:
    name: teaching-agents-network
```

### Running with Docker Compose

```bash
# Set environment variable
export GOOGLE_CLOUD_PROJECT=your-project-id

# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Google Cloud Run Deployment

### Prerequisites

- Google Cloud Project with billing enabled
- Cloud Run API enabled
- Artifact Registry API enabled

### Step 1: Setup Artifact Registry

```bash
# Create repository
gcloud artifacts repositories create teaching-agents \
    --repository-format=docker \
    --location=us-central1

# Configure Docker authentication
gcloud auth configure-docker us-central1-docker.pkg.dev
```

### Step 2: Build and Push Images

```bash
# Set variables
PROJECT_ID=your-project-id
REGION=us-central1
REPO=teaching-agents

# Build and push Scholar Agent
cd remote_agents/scholar_agent
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/scholar-agent:latest .
docker push us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/scholar-agent:latest

# Build and push Teacher Agent
cd ../teacher_agent
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/teacher-agent:latest .
docker push us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/teacher-agent:latest

# Build and push Researcher Agent
cd ../..
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/researcher-agent:latest .
docker push us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/researcher-agent:latest
```

### Step 3: Deploy to Cloud Run

#### Deploy Scholar Agent

```bash
gcloud run deploy scholar-agent \
    --image=us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/scholar-agent:latest \
    --platform=managed \
    --region=us-central1 \
    --allow-unauthenticated \
    --port=10000 \
    --memory=2Gi \
    --cpu=1 \
    --timeout=300 \
    --concurrency=10 \
    --set-env-vars="API_KEY=prod_scholar_key_456" \
    --set-env-vars="GCLOUD_LOCATION=us-central1" \
    --set-env-vars="GCLOUD_PROJECT_ID=$PROJECT_ID" \
    --set-env-vars="PORT=10000"
```

#### Deploy Teacher Agent

```bash
gcloud run deploy teacher-agent \
    --image=us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/teacher-agent:latest \
    --platform=managed \
    --region=us-central1 \
    --allow-unauthenticated \
    --port=10001 \
    --memory=2Gi \
    --cpu=1 \
    --timeout=300 \
    --concurrency=10 \
    --set-env-vars="API_KEY=prod_teacher_key_789" \
    --set-env-vars="GCLOUD_LOCATION=us-central1" \
    --set-env-vars="GCLOUD_PROJECT_ID=$PROJECT_ID" \
    --set-env-vars="PORT=10001"
```

#### Deploy Researcher Agent

First, get the URLs of the deployed agents:

```bash
SCHOLAR_URL=$(gcloud run services describe scholar-agent --region=us-central1 --format="value(status.url)")
TEACHER_URL=$(gcloud run services describe teacher-agent --region=us-central1 --format="value(status.url)")

gcloud run deploy researcher-agent \
    --image=us-central1-docker.pkg.dev/$PROJECT_ID/$REPO/researcher-agent:latest \
    --platform=managed \
    --region=us-central1 \
    --allow-unauthenticated \
    --port=8080 \
    --memory=2Gi \
    --cpu=1 \
    --timeout=300 \
    --concurrency=100 \
    --set-env-vars="SCHOLAR_AGENT_AUTH=prod_scholar_key_456" \
    --set-env-vars="SCHOLAR_AGENT_URL=$SCHOLAR_URL" \
    --set-env-vars="TEACHER_AGENT_AUTH=prod_teacher_key_789" \
    --set-env-vars="TEACHER_AGENT_URL=$TEACHER_URL" \
    --set-env-vars="GOOGLE_GENAI_USE_VERTEXAI=TRUE" \
    --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID" \
    --set-env-vars="GOOGLE_CLOUD_LOCATION=us-central1"
```

### Step 4: Custom Domain (Optional)

```bash
# Map custom domain
gcloud domains mappings create \
    --service=researcher-agent \
    --domain=teaching-agents.yourdomain.com \
    --region=us-central1
```

## Kubernetes Deployment

### Prerequisites

- GKE cluster or other Kubernetes cluster
- kubectl configured
- Helm (optional, for advanced deployments)

### Step 1: Create Namespace

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: teaching-agents
```

```bash
kubectl apply -f namespace.yaml
```

### Step 2: Create ConfigMaps and Secrets

```yaml
# config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: teaching-agents-config
  namespace: teaching-agents
data:
  GCLOUD_LOCATION: "us-central1"
  GOOGLE_GENAI_USE_VERTEXAI: "TRUE"
---
apiVersion: v1
kind: Secret
metadata:
  name: teaching-agents-secrets
  namespace: teaching-agents
type: Opaque
data:
  API_KEY: cHJvZF9hcGlfa2V5XzEyMw== # base64 encoded
  GOOGLE_CLOUD_PROJECT: eW91ci1wcm9qZWN0LWlk # base64 encoded
```

### Step 3: Deploy Services

```yaml
# scholar-agent.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scholar-agent
  namespace: teaching-agents
spec:
  replicas: 2
  selector:
    matchLabels:
      app: scholar-agent
  template:
    metadata:
      labels:
        app: scholar-agent
    spec:
      containers:
        - name: scholar-agent
          image: us-central1-docker.pkg.dev/your-project/teaching-agents/scholar-agent:latest
          ports:
            - containerPort: 10000
          env:
            - name: PORT
              value: "10000"
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: teaching-agents-secrets
                  key: API_KEY
            - name: GCLOUD_PROJECT_ID
              valueFrom:
                secretKeyRef:
                  name: teaching-agents-secrets
                  key: GOOGLE_CLOUD_PROJECT
          envFrom:
            - configMapRef:
                name: teaching-agents-config
          resources:
            requests:
              memory: "1Gi"
              cpu: "500m"
            limits:
              memory: "2Gi"
              cpu: "1000m"
          livenessProbe:
            httpGet:
              path: /.well-known/agent
              port: 10000
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /.well-known/agent
              port: 10000
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: scholar-agent-service
  namespace: teaching-agents
spec:
  selector:
    app: scholar-agent
  ports:
    - port: 80
      targetPort: 10000
  type: ClusterIP
```

### Step 4: Deploy Ingress

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: teaching-agents-ingress
  namespace: teaching-agents
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - teaching-agents.yourdomain.com
      secretName: teaching-agents-tls
  rules:
    - host: teaching-agents.yourdomain.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: researcher-agent-service
                port:
                  number: 80
```

## Environment Configuration

### Development Environment

```env
# Development settings
DEBUG=true
LOG_LEVEL=DEBUG
API_KEY=dev_key_123
TIMEOUT=30
CONCURRENCY=1
```

### Staging Environment

```env
# Staging settings
DEBUG=false
LOG_LEVEL=INFO
API_KEY=staging_key_456
TIMEOUT=60
CONCURRENCY=5
```

### Production Environment

```env
# Production settings
DEBUG=false
LOG_LEVEL=WARNING
API_KEY=prod_key_789
TIMEOUT=120
CONCURRENCY=10
ENABLE_MONITORING=true
```

### Security Best Practices

1. **Use Secret Management**

   ```bash
   # Google Secret Manager
   gcloud secrets create api-key --data-file=api-key.txt

   # Reference in Cloud Run
   --set-secrets="API_KEY=api-key:latest"
   ```

2. **Service Account Configuration**

   ```bash
   # Create service account
   gcloud iam service-accounts create teaching-agents-sa

   # Grant permissions
   gcloud projects add-iam-policy-binding $PROJECT_ID \
       --member="serviceAccount:teaching-agents-sa@$PROJECT_ID.iam.gserviceaccount.com" \
       --role="roles/aiplatform.user"
   ```

3. **Network Security**
   ```yaml
   # Network policy for Kubernetes
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: teaching-agents-netpol
     namespace: teaching-agents
   spec:
     podSelector:
       matchLabels:
         app: researcher-agent
     policyTypes:
       - Ingress
       - Egress
     ingress:
       - from:
           - namespaceSelector:
               matchLabels:
                 name: ingress-system
   ```

## Monitoring and Logging

### Google Cloud Monitoring

1. **Enable APIs**

   ```bash
   gcloud services enable monitoring.googleapis.com
   gcloud services enable logging.googleapis.com
   ```

2. **Custom Metrics**

   ```python
   from google.cloud import monitoring_v3

   def record_request_metric():
       client = monitoring_v3.MetricServiceClient()
       series = monitoring_v3.TimeSeries()
       # Add metric recording logic
   ```

3. **Alerting Policies**
   ```bash
   # Create uptime check
   gcloud alpha monitoring uptime create \
       --display-name="Teaching Agents Uptime" \
       --http-check-path="/" \
       --hostname="your-app-url.com"
   ```

### Application Logging

```python
import logging
import json
from google.cloud import logging as cloud_logging

# Configure structured logging
def setup_logging():
    if os.getenv('GOOGLE_CLOUD_PROJECT'):
        client = cloud_logging.Client()
        client.setup_logging()

    logging.basicConfig(
        level=os.getenv('LOG_LEVEL', 'INFO'),
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

# Log structured data
def log_agent_interaction(agent_name, task_id, status):
    logging.info(json.dumps({
        'event': 'agent_interaction',
        'agent_name': agent_name,
        'task_id': task_id,
        'status': status,
        'timestamp': datetime.utcnow().isoformat()
    }))
```

### Health Checks

```python
# health.py
from fastapi import FastAPI
from starlette.responses import JSONResponse

app = FastAPI()

@app.get("/health")
async def health_check():
    """Basic health check endpoint"""
    try:
        # Check database connectivity
        # Check external service connectivity
        return JSONResponse({
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "version": "1.0.0"
        })
    except Exception as e:
        return JSONResponse(
            status_code=503,
            content={
                "status": "unhealthy",
                "error": str(e),
                "timestamp": datetime.utcnow().isoformat()
            }
        )

@app.get("/ready")
async def readiness_check():
    """Readiness check for Kubernetes"""
    # Check if service can accept traffic
    return JSONResponse({"status": "ready"})
```

## Scaling Considerations

### Horizontal Pod Autoscaler (HPA)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: scholar-agent-hpa
  namespace: teaching-agents
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: scholar-agent
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

### Cloud Run Auto Scaling

```bash
gcloud run services update scholar-agent \
    --min-instances=1 \
    --max-instances=10 \
    --concurrency=10 \
    --cpu-throttling \
    --region=us-central1
```

## Troubleshooting

### Common Issues

1. **Agent Connection Failures**

   ```bash
   # Check agent card endpoints
   curl -v http://agent-url/.well-known/agent

   # Check logs
   kubectl logs -f deployment/scholar-agent -n teaching-agents
   ```

2. **Authentication Errors**

   ```bash
   # Verify service account permissions
   gcloud projects get-iam-policy $PROJECT_ID

   # Test API access
   gcloud auth application-default print-access-token
   ```

3. **Resource Limits**

   ```bash
   # Check resource usage
   kubectl top pods -n teaching-agents

   # Check events
   kubectl get events -n teaching-agents --sort-by='.lastTimestamp'
   ```

### Debugging Commands

```bash
# Port forward for local testing
kubectl port-forward svc/scholar-agent-service 10000:80 -n teaching-agents

# Execute into pod
kubectl exec -it deployment/scholar-agent -n teaching-agents -- /bin/bash

# View detailed pod information
kubectl describe pod <pod-name> -n teaching-agents
```

This deployment guide provides comprehensive instructions for deploying the Teaching Agents system across different environments and scales.
