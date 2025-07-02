# Teaching Agents API Reference

## Overview

This document provides comprehensive API reference for the Teaching Agents system, including all data types, endpoints, and communication protocols used in the A2A (Agent-to-Agent) implementation.

## Core Data Types

### TaskState

Enumeration representing the state of a task.

```python
class TaskState(str, Enum):
    SUBMITTED = "submitted"        # Task has been submitted
    WORKING = "working"           # Task is being processed
    INPUT_REQUIRED = "input-required"  # Task requires user input
    COMPLETED = "completed"       # Task completed successfully
    CANCELED = "canceled"         # Task was canceled
    FAILED = "failed"            # Task failed with error
    UNKNOWN = "unknown"          # Task state is unknown
```

### Message Parts

#### TextPart

Represents text content in messages.

```python
class TextPart(BaseModel):
    type: Literal["text"] = "text"
    text: str
    metadata: dict[str, Any] | None = None
```

**Example:**

```json
{
  "type": "text",
  "text": "Please research quantum computing",
  "metadata": { "priority": "high" }
}
```

#### FilePart

Represents file content in messages.

```python
class FilePart(BaseModel):
    type: Literal["file"] = "file"
    file: FileContent
    metadata: dict[str, Any] | None = None

class FileContent(BaseModel):
    name: str | None = None
    mimeType: str | None = None
    bytes: str | None = None  # Base64 encoded
    uri: str | None = None    # Either bytes OR uri required
```

**Example:**

```json
{
  "type": "file",
  "file": {
    "name": "document.pdf",
    "mimeType": "application/pdf",
    "uri": "gs://bucket/document.pdf"
  }
}
```

#### DataPart

Represents structured data in messages.

```python
class DataPart(BaseModel):
    type: Literal["data"] = "data"
    data: dict[str, Any]
    metadata: dict[str, Any] | None = None
```

**Example:**

```json
{
  "type": "data",
  "data": {
    "topic": "quantum computing",
    "difficulty": "advanced",
    "duration": "60 minutes"
  }
}
```

### Message

Represents a communication message between agents.

```python
class Message(BaseModel):
    role: Literal["user", "agent"]
    parts: List[Part]  # Union of TextPart, FilePart, DataPart
    metadata: dict[str, Any] | None = None
```

**Example:**

```json
{
  "role": "user",
  "parts": [
    {
      "type": "text",
      "text": "Create a lesson plan for quantum computing"
    }
  ],
  "metadata": {
    "conversation_id": "conv-123",
    "message_id": "msg-456"
  }
}
```

### Task

Represents a unit of work with status and metadata.

```python
class Task(BaseModel):
    id: str
    sessionId: str | None = None
    status: TaskStatus
    artifacts: List[Artifact] | None = None
    history: List[Message] | None = None
    metadata: dict[str, Any] | None = None
```

### TaskStatus

Represents the current status of a task.

```python
class TaskStatus(BaseModel):
    state: TaskState
    message: Message | None = None
    timestamp: datetime = Field(default_factory=datetime.now)
```

### Artifact

Represents output artifacts produced by agents.

```python
class Artifact(BaseModel):
    name: str | None = None
    description: str | None = None
    parts: List[Part]
    metadata: dict[str, Any] | None = None
    index: int = 0
    append: bool | None = None      # For streaming artifacts
    lastChunk: bool | None = None   # Indicates final chunk
```

**Example:**

```json
{
  "name": "lesson_plan",
  "description": "Quantum Computing Lesson Plan",
  "parts": [
    {
      "type": "text",
      "text": "# Quantum Computing Lesson\n\n## Introduction\n..."
    }
  ],
  "metadata": {
    "format": "markdown",
    "estimated_duration": "60 minutes"
  }
}
```

## Agent Card Schema

### AgentCard

Describes agent capabilities and connection information.

```python
class AgentCard(BaseModel):
    name: str
    description: str | None = None
    url: str
    provider: AgentProvider | None = None
    version: str
    documentationUrl: str | None = None
    capabilities: AgentCapabilities
    authentication: AgentAuthentication | None = None
    defaultInputModes: List[str] = ["text"]
    defaultOutputModes: List[str] = ["text"]
    skills: List[AgentSkill]
```

### AgentProvider

Information about the agent provider.

```python
class AgentProvider(BaseModel):
    organization: str
    url: str | None = None
```

### AgentCapabilities

Agent capability flags.

```python
class AgentCapabilities(BaseModel):
    streaming: bool = False               # Supports streaming responses
    pushNotifications: bool = False       # Supports push notifications
    stateTransitionHistory: bool = False  # Maintains state history
```

### AgentAuthentication

Authentication requirements for the agent.

```python
class AgentAuthentication(BaseModel):
    schemes: List[str]        # ["bearer", "basic", "api-key"]
    credentials: str | None = None
```

### AgentSkill

Describes a specific skill or capability of an agent.

```python
class AgentSkill(BaseModel):
    id: str
    name: str
    description: str | None = None
    tags: List[str] | None = None
    examples: List[str] | None = None
    inputModes: List[str] | None = None   # ["text", "image", "audio"]
    outputModes: List[str] | None = None  # ["text", "image", "video"]
```

**Example Agent Card:**

```json
{
  "name": "scholar_agent",
  "description": "Specialized research agent",
  "url": "http://localhost:10000",
  "version": "1.0.0",
  "capabilities": {
    "streaming": false,
    "pushNotifications": false,
    "stateTransitionHistory": true
  },
  "authentication": {
    "schemes": ["bearer"],
    "credentials": null
  },
  "skills": [
    {
      "id": "research",
      "name": "Topic Research",
      "description": "Research and provide detailed information about topics",
      "tags": ["research", "information", "knowledge"],
      "inputModes": ["text"],
      "outputModes": ["text"]
    }
  ]
}
```

## JSON-RPC Protocol

### Base Messages

#### JSONRPCMessage

Base class for all JSON-RPC messages.

```python
class JSONRPCMessage(BaseModel):
    jsonrpc: Literal["2.0"] = "2.0"
    id: int | str | None = Field(default_factory=lambda: uuid4().hex)
```

#### JSONRPCRequest

Base class for JSON-RPC requests.

```python
class JSONRPCRequest(JSONRPCMessage):
    method: str
    params: dict[str, Any] | None = None
```

#### JSONRPCResponse

Base class for JSON-RPC responses.

```python
class JSONRPCResponse(JSONRPCMessage):
    result: Any | None = None
    error: JSONRPCError | None = None
```

### Task Operations

#### Send Task

**Request:**

```python
class SendTaskRequest(JSONRPCRequest):
    method: Literal["tasks/send"] = "tasks/send"
    params: TaskSendParams

class TaskSendParams(BaseModel):
    id: str
    sessionId: str = Field(default_factory=lambda: uuid4().hex)
    message: Message
    acceptedOutputModes: Optional[List[str]] = None
    pushNotification: PushNotificationConfig | None = None
    historyLength: int | None = None
    metadata: dict[str, Any] | None = None
```

**Response:**

```python
class SendTaskResponse(JSONRPCResponse):
    result: Task | None = None
```

**Example Request:**

```json
{
  "jsonrpc": "2.0",
  "method": "tasks/send",
  "id": "req-123",
  "params": {
    "id": "task-456",
    "sessionId": "session-789",
    "message": {
      "role": "user",
      "parts": [
        {
          "type": "text",
          "text": "Research quantum computing applications"
        }
      ]
    },
    "acceptedOutputModes": ["text", "text/plain"],
    "metadata": {
      "priority": "high"
    }
  }
}
```

#### Get Task

**Request:**

```python
class GetTaskRequest(JSONRPCRequest):
    method: Literal["tasks/get"] = "tasks/get"
    params: TaskQueryParams

class TaskQueryParams(BaseModel):
    id: str
    historyLength: int | None = None
    metadata: dict[str, Any] | None = None
```

**Response:**

```python
class GetTaskResponse(JSONRPCResponse):
    result: Task | None = None
```

#### Cancel Task

**Request:**

```python
class CancelTaskRequest(JSONRPCRequest):
    method: Literal["tasks/cancel"] = "tasks/cancel"
    params: TaskIdParams

class TaskIdParams(BaseModel):
    id: str
    metadata: dict[str, Any] | None = None
```

**Response:**

```python
class CancelTaskResponse(JSONRPCResponse):
    result: Task | None = None
```

### Streaming Support

#### Send Task with Streaming

**Request:**

```python
class SendTaskStreamingRequest(JSONRPCRequest):
    method: Literal["tasks/sendSubscribe"] = "tasks/sendSubscribe"
    params: TaskSendParams
```

**Response Events:**

```python
class SendTaskStreamingResponse(JSONRPCResponse):
    result: TaskStatusUpdateEvent | TaskArtifactUpdateEvent | None = None

class TaskStatusUpdateEvent(BaseModel):
    id: str
    status: TaskStatus
    final: bool = False
    metadata: dict[str, Any] | None = None

class TaskArtifactUpdateEvent(BaseModel):
    id: str
    artifact: Artifact
    metadata: dict[str, Any] | None = None
```

## Error Codes

### Standard JSON-RPC Errors

```python
class JSONParseError(JSONRPCError):
    code: int = -32700
    message: str = "Invalid JSON payload"

class InvalidRequestError(JSONRPCError):
    code: int = -32600
    message: str = "Request payload validation error"

class MethodNotFoundError(JSONRPCError):
    code: int = -32601
    message: str = "Method not found"

class InvalidParamsError(JSONRPCError):
    code: int = -32602
    message: str = "Invalid parameters"

class InternalError(JSONRPCError):
    code: int = -32603
    message: str = "Internal error"
```

### A2A-Specific Errors

```python
class TaskNotFoundError(JSONRPCError):
    code: int = -32001
    message: str = "Task not found"

class TaskNotCancelableError(JSONRPCError):
    code: int = -32002
    message: str = "Task cannot be canceled"

class PushNotificationNotSupportedError(JSONRPCError):
    code: int = -32003
    message: str = "Push Notification is not supported"

class UnsupportedOperationError(JSONRPCError):
    code: int = -32004
    message: str = "This operation is not supported"

class ContentTypeNotSupportedError(JSONRPCError):
    code: int = -32005
    message: str = "Incompatible content types"
```

## HTTP Endpoints

### Agent Card Endpoint

**GET** `/.well-known/agent`

Returns the agent card describing capabilities and connection information.

**Response:**

```json
{
  "name": "scholar_agent",
  "description": "Specialized research agent",
  "url": "http://localhost:10000",
  "version": "1.0.0",
  "capabilities": {
    "streaming": false,
    "pushNotifications": false
  },
  "authentication": {
    "schemes": ["bearer"]
  },
  "skills": [...]
}
```

### Task Management Endpoint

**POST** `/`

Main endpoint for JSON-RPC task operations.

**Headers:**

- `Content-Type: application/json`
- `Authorization: Bearer <token>` (if required)

**Request Body:** JSON-RPC request (see examples above)

**Response:** JSON-RPC response with task data

## A2A Client Library

### A2AClient

Main client class for communicating with A2A agents.

```python
class A2AClient:
    def __init__(self, agent_card: AgentCard, auth: str, agent_url: str):
        """Initialize A2A client.

        Args:
            agent_card: Agent capability description
            auth: Authentication credential
            agent_url: Agent endpoint URL
        """

    async def send_task(self, payload: dict[str, Any]) -> SendTaskResponse:
        """Send a task to the agent.

        Args:
            payload: Task parameters as dictionary

        Returns:
            SendTaskResponse with task result

        Raises:
            A2AClientHTTPError: HTTP communication error
            A2AClientJSONError: JSON parsing error
        """
```

### A2ACardResolver

Utility for discovering and retrieving agent cards.

```python
class A2ACardResolver:
    def __init__(self, agent_url: str):
        """Initialize card resolver.

        Args:
            agent_url: Base URL of the agent
        """

    def get_agent_card(self) -> AgentCard:
        """Retrieve agent card.

        Returns:
            AgentCard with agent capabilities

        Raises:
            httpx.HTTPError: Network or HTTP error
        """
```

## Authentication

### Supported Schemes

1. **Bearer Token**

   ```
   Authorization: Bearer <token>
   ```

2. **Basic Authentication**

   ```
   Authorization: Basic <base64(credentials)>
   ```

3. **API Key** (custom header)
   ```
   X-API-Key: <api-key>
   ```

### Configuration

Authentication is configured in the agent card:

```json
{
  "authentication": {
    "schemes": ["bearer"],
    "credentials": null
  }
}
```

## Example Workflows

### Research and Teaching Workflow

1. **User Query**: User asks about a topic
2. **Task Routing**: Researcher agent routes to Scholar agent
3. **Research Phase**: Scholar agent researches the topic
4. **Teaching Phase**: Researcher routes research to Teacher agent
5. **Lesson Creation**: Teacher agent creates lesson plan
6. **Response**: Final lesson plan returned to user

### Message Flow

```
POST /
{
  "jsonrpc": "2.0",
  "method": "tasks/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{"type": "text", "text": "Explain quantum computing"}]
    }
  }
}

↓

{
  "jsonrpc": "2.0",
  "result": {
    "id": "task-123",
    "status": {
      "state": "completed",
      "timestamp": "2025-01-01T10:00:00Z"
    },
    "artifacts": [{
      "name": "lesson_plan",
      "parts": [{"type": "text", "text": "# Quantum Computing\n..."}]
    }]
  }
}
```

## Best Practices

### Error Handling

Always handle specific error types:

```python
try:
    response = await client.send_task(payload)
except A2AClientHTTPError as e:
    if e.status_code == 404:
        # Handle agent not found
    elif e.status_code == 401:
        # Handle authentication error
except A2AClientJSONError as e:
    # Handle JSON parsing error
```

### Session Management

Use consistent session IDs for related tasks:

```python
session_id = str(uuid.uuid4())

# Send related tasks with same session_id
task1 = TaskSendParams(
    id=str(uuid.uuid4()),
    sessionId=session_id,
    message=research_message
)

task2 = TaskSendParams(
    id=str(uuid.uuid4()),
    sessionId=session_id,
    message=teaching_message
)
```

### Timeout Configuration

Set appropriate timeouts for long-running tasks:

```python
async with httpx.AsyncClient(timeout=120.0) as client:
    response = await client.post(url, json=request_data)
```

This API reference provides comprehensive documentation for implementing and working with the Teaching Agents A2A protocol system.
