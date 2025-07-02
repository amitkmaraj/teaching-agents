# Teaching Agents - System Architecture

## Overview

The Teaching Agents project demonstrates an Agent-to-Agent (A2A) protocol implementation for orchestrating specialized AI agents. The system consists of a main orchestrator agent (Researcher Agent) that communicates with remote specialized agents (Scholar Agent and Teacher Agent) to provide comprehensive research and teaching capabilities.

## System Components

### 1. Researcher Agent (Orchestrator)

- **Location**: `researcher/`
- **Role**: Main orchestrator that coordinates tasks between remote agents
- **Technology**: Google ADK (Agent Development Kit)
- **Key Features**:
  - Receives user queries about topics to research
  - Routes research requests to Scholar Agent
  - Sends research results to Teacher Agent for lesson planning
  - Provides final synthesized response to user

### 2. Scholar Agent (Remote Agent)

- **Location**: `remote_agents/scholar_agent/`
- **Role**: Specialized researcher that provides detailed information about topics
- **Technology**: LangGraph with ChatVertexAI
- **Key Features**:
  - Researches topics using internal knowledge
  - Provides detailed, factual information
  - Returns structured responses with status indicators

### 3. Teacher Agent (Remote Agent)

- **Location**: `remote_agents/teacher_agent/`
- **Role**: Specialized educator that creates lesson plans from research data
- **Technology**: LangGraph with ChatVertexAI
- **Key Features**:
  - Transforms research information into teachable content
  - Creates structured lesson plans
  - Provides digestible learning materials

### 4. A2A Client Library

- **Location**: `a2a_client/`
- **Role**: Handles communication between agents using A2A protocol
- **Key Components**:
  - `client.py`: Core A2A client implementation
  - `card_resolver.py`: Agent card discovery and resolution
  - `push_notification_auth.py`: Authentication for push notifications

## Architecture Flow

```
User Query
    ↓
Researcher Agent (Orchestrator)
    ↓
Scholar Agent (Research) → Research Results
    ↓
Teacher Agent (Lesson Planning) → Lesson Plan
    ↓
Final Response to User
```

## Communication Protocol

### A2A Protocol

The system uses a JSON-RPC based Agent-to-Agent protocol for communication:

1. **Agent Discovery**: Agents publish their capabilities through Agent Cards
2. **Task Submission**: Tasks are sent using structured JSON-RPC messages
3. **Status Updates**: Real-time status updates during task execution
4. **Result Delivery**: Final results are returned with metadata

### Message Types

- `TaskSendParams`: Initial task submission
- `TaskStatusUpdateEvent`: Status updates during execution
- `TaskArtifactUpdateEvent`: Artifact updates and results
- `AgentCard`: Agent capability advertisement

## Data Models

### Core Types (a2a_types.py)

- **Task**: Represents a unit of work with status and metadata
- **Message**: Communication between agents with role and content
- **Part**: Content parts (text, file, data)
- **AgentCard**: Agent capability and endpoint information
- **TaskState**: Execution states (submitted, working, completed, etc.)

## Security & Authentication

### Authentication Schemes

- **Bearer Token**: For API key-based authentication
- **Basic Auth**: For username/password authentication
- **Configurable**: Each agent can specify supported schemes

### API Keys

- Scholar Agent: Uses `pizza123` as default API key
- Teacher Agent: Uses `pizza123` as default API key
- Environment-based configuration for production use

## Deployment Architecture

### Local Development

```
Researcher Agent (Port 8080)
    ↓
Scholar Agent (Port 10000)
Teacher Agent (Port 10001)
```

### Production (Docker)

- Each agent runs in separate containers
- Environment variables for configuration
- Cloud Run deployment support
- Load balancing and scaling capabilities

## Technology Stack

### Core Technologies

- **Google ADK**: Agent Development Kit for orchestrator
- **LangGraph**: Graph-based agent framework for remote agents
- **ChatVertexAI**: Google's Gemini model integration
- **FastAPI/Starlette**: Web framework for A2A endpoints
- **Gradio**: Web UI for user interaction

### Dependencies

- `google-adk>=0.3.0`: Core agent framework
- `gradio>=5.28.0`: Web interface
- `httpx>=0.28.1`: HTTP client for A2A communication
- `pydantic>=2.10.6`: Data validation and serialization
- `uvicorn>=0.34.0`: ASGI server

## Scalability Considerations

### Horizontal Scaling

- Remote agents can be deployed on multiple instances
- Load balancing across agent instances
- Session management for distributed scenarios

### Performance Optimization

- Async/await patterns for non-blocking operations
- Connection pooling for HTTP clients
- Caching strategies for agent cards and responses

## Error Handling

### A2A Protocol Errors

- `TaskNotFoundError`: Task doesn't exist
- `TaskNotCancelableError`: Task cannot be canceled
- `ContentTypeNotSupportedError`: Unsupported content type
- `InternalError`: Generic server errors

### Agent-Specific Errors

- Network connectivity issues
- Authentication failures
- Model inference errors
- Timeout handling

## Monitoring & Observability

### Logging

- Structured logging with request/response details
- Error tracking and alerting
- Performance metrics collection

### Health Checks

- Agent availability monitoring
- A2A protocol compliance checks
- End-to-end workflow validation

## Configuration Management

### Environment Variables

- `GCLOUD_PROJECT_ID`: Google Cloud project identifier
- `GCLOUD_LOCATION`: Region for Vertex AI
- `SCHOLAR_AGENT_URL`: Scholar agent endpoint
- `TEACHER_AGENT_URL`: Teacher agent endpoint
- Authentication keys and credentials

### Configuration Files

- `.env` files for local development
- `pyproject.toml` for Python dependencies
- Docker configurations for containerized deployment
