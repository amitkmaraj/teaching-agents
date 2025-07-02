# Teaching Agents Codelab: Building Agent-to-Agent Communication

## Overview

In this codelab, you'll learn how to build a distributed AI agent system using the Agent-to-Agent (A2A) protocol. You'll create a research and teaching system where specialized agents communicate to provide comprehensive educational content.

**What you'll build:**

- A Researcher Agent that orchestrates tasks
- A Scholar Agent that researches topics
- A Teacher Agent that creates lesson plans
- A web interface for user interaction

**What you'll learn:**

- Agent-to-Agent (A2A) protocol implementation
- Distributed agent architecture
- Google ADK (Agent Development Kit) usage
- LangGraph for agent workflows
- Async communication patterns

**Prerequisites:**

- Python 3.12+
- Google Cloud Project with Vertex AI API enabled
- Basic understanding of async/await patterns
- Familiarity with REST APIs

## Lab 1: Understanding the A2A Protocol

### What is Agent-to-Agent Communication?

The A2A protocol enables AI agents to communicate and collaborate on complex tasks. Instead of building monolithic agents, you can create specialized agents that excel at specific tasks.

### Key Concepts

1. **Agent Cards**: Describe agent capabilities and endpoints
2. **Tasks**: Units of work sent between agents
3. **JSON-RPC**: Communication protocol for agent interaction
4. **Status Updates**: Real-time progress reporting

### A2A Message Flow

```
Client → Researcher Agent → Scholar Agent → Research Data
                         → Teacher Agent → Lesson Plan
                         → Response to Client
```

## Lab 2: Setting Up the Development Environment

### Step 1: Clone and Setup

```bash
# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Python and dependencies
uv python install 3.12
uv sync --frozen
```

### Step 2: Google Cloud Setup

```bash
# Authenticate with Google Cloud
gcloud auth application-default login

# Enable required APIs
gcloud services enable aiplatform.googleapis.com
```

### Step 3: Environment Configuration

Create environment files for each agent:

**Scholar Agent** (`remote_agents/scholar_agent/.env`):

```env
API_KEY=pizza123
GCLOUD_LOCATION=us-central1
GCLOUD_PROJECT_ID=your-project-id
```

**Teacher Agent** (`remote_agents/teacher_agent/.env`):

```env
API_KEY=pizza123
GCLOUD_LOCATION=us-central1
GCLOUD_PROJECT_ID=your-project-id
```

**Researcher Agent** (`researcher/.env`):

```env
SCHOLAR_AGENT_AUTH=pizza123
SCHOLAR_AGENT_URL=http://localhost:10000
TEACHER_AGENT_AUTH=pizza123
TEACHER_AGENT_URL=http://localhost:10001
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=us-central1
```

## Lab 3: Building the Scholar Agent

### Understanding the Scholar Agent

The Scholar Agent is a specialized researcher that provides detailed information about topics using LangGraph.

### Key Components

1. **Agent Class**: Main logic and system instructions
2. **Response Format**: Structured output with status indicators
3. **LangGraph Integration**: Workflow management
4. **Memory Management**: Session state handling

### Code Walkthrough

```python
class ScholarAgent:
    SYSTEM_INSTRUCTION = """
    You are a specialized scholar. You can research and provide
    detailed information about certain topics.
    """

    def __init__(self):
        self.model = ChatVertexAI(model="gemini-2.5-flash")
        self.graph = create_react_agent(
            self.model,
            tools=[],
            checkpointer=memory,
            prompt=self.SYSTEM_INSTRUCTION,
            response_format=ResponseFormat,
        )
```

### Response Format Structure

```python
class ResponseFormat(BaseModel):
    status: Literal["working", "completed", "error"] = "working"
    message: str
```

### Step-by-Step Implementation

1. **Start the Scholar Agent**:

```bash
cd remote_agents/scholar_agent
uv run .
```

2. **Test the Agent**:

```bash
curl -X POST http://localhost:10000 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer pizza123" \
  -d '{"jsonrpc": "2.0", "method": "tasks/send", "params": {...}}'
```

## Lab 4: Building the Teacher Agent

### Understanding the Teacher Agent

The Teacher Agent transforms research information into structured lesson plans.

### Key Differences from Scholar Agent

- **Purpose**: Creates teachable content vs. researching
- **Input**: Processes research data from Scholar Agent
- **Output**: Structured lesson plans and learning materials

### Implementation Details

```python
class TeacherAgent:
    SYSTEM_INSTRUCTION = """
    You are a specialized teacher. Given information about a
    specific topic, you can break it down into a digestible
    learning plan and details, suitable for a student.
    """
```

### Starting the Teacher Agent

```bash
cd remote_agents/teacher_agent
uv run .
```

## Lab 5: Building the Researcher Agent (Orchestrator)

### Understanding the Orchestrator Pattern

The Researcher Agent coordinates between specialized agents:

1. Receives user queries
2. Routes research requests to Scholar Agent
3. Sends research results to Teacher Agent
4. Synthesizes final response

### Key Components

#### 1. Agent Discovery and Connection

```python
class ResearcherAgent:
    def __init__(self, remote_agent_addresses: List[str]):
        self.remote_agent_connections: dict[str, RemoteAgentConnections] = {}
        self.cards: dict[str, AgentCard] = {}

        for address in remote_agent_addresses:
            card_resolver = A2ACardResolver(address)
            card = card_resolver.get_agent_card()
            # Store agent connections and capabilities
```

#### 2. Task Routing Logic

```python
async def send_task(self, agent_name: str, task: str, tool_context: ToolContext):
    """Sends a task to remote agent"""
    if agent_name not in self.remote_agent_connections:
        raise ValueError(f"Agent {agent_name} not found")

    client = self.remote_agent_connections[agent_name]
    # Send task and handle response
```

#### 3. Session Management

```python
def before_model_callback(self, callback_context: CallbackContext, llm_request):
    state = callback_context.state
    if "session_active" not in state or not state["session_active"]:
        if "session_id" not in state:
            state["session_id"] = str(uuid.uuid4())
        state["session_active"] = True
```

## Lab 6: Understanding A2A Communication

### A2A Client Implementation

The A2A client handles HTTP communication between agents:

```python
class A2AClient:
    def __init__(self, agent_card: AgentCard, auth: str, agent_url: str):
        self.url = agent_url
        self.auth_header = self._setup_auth(agent_card, auth)

    async def send_task(self, payload: dict[str, Any]) -> SendTaskResponse:
        request = SendTaskRequest(params=payload)
        return SendTaskResponse(**await self._send_request(request))
```

### Message Structure

#### Task Send Parameters

```python
class TaskSendParams(BaseModel):
    id: str
    sessionId: str
    message: Message
    acceptedOutputModes: Optional[List[str]] = None
    pushNotification: PushNotificationConfig | None = None
    metadata: dict[str, Any] | None = None
```

#### Agent Card Format

```python
class AgentCard(BaseModel):
    name: str
    description: str | None = None
    url: str
    capabilities: AgentCapabilities
    authentication: AgentAuthentication | None = None
    skills: List[AgentSkill]
```

## Lab 7: Building the Web Interface

### Gradio Integration

The system uses Gradio for the web interface:

```python
async def get_response_from_agent(
    message: str,
    history: List[Dict[str, Any]],
) -> str:
    events_iterator = PURCHASING_AGENT_RUNNER.run_async(
        user_id=USER_ID,
        session_id=SESSION_ID,
        new_message=types.Content(role="user", parts=[types.Part(text=message)]),
    )

    responses = []
    async for event in events_iterator:
        # Process events and build response
        if event.is_final_response():
            yield responses
            break
```

### Event Handling

The interface handles different types of events:

1. **Function Calls**: Tool invocations by the agent
2. **Function Responses**: Results from tool calls
3. **Final Responses**: Completed agent responses
4. **Errors**: Error handling and escalation

## Lab 8: Testing the Complete System

### Step 1: Start All Agents

Terminal 1 - Scholar Agent:

```bash
cd remote_agents/scholar_agent
uv run .
```

Terminal 2 - Teacher Agent:

```bash
cd remote_agents/teacher_agent
uv run .
```

Terminal 3 - Researcher Agent:

```bash
uv run researcher_demo.py
```

### Step 2: Test the System

1. Open `http://localhost:8080` in your browser
2. Enter a research query: "Tell me about quantum computing"
3. Observe the agent interactions:
   - Researcher routes to Scholar Agent
   - Scholar provides research data
   - Researcher sends data to Teacher Agent
   - Teacher creates lesson plan
   - Final response presented to user

### Step 3: Monitor Agent Communication

Check the terminal logs to see A2A protocol messages:

```
Send Remote Agent Task Request: {
  "jsonrpc": "2.0",
  "method": "tasks/send",
  "params": {
    "id": "task-123",
    "message": {
      "role": "user",
      "parts": [{"type": "text", "text": "Research quantum computing"}]
    }
  }
}
```

## Lab 9: Advanced Features

### Custom Agent Skills

Add new skills to your agents by defining them in the Agent Card:

```python
class AgentSkill(BaseModel):
    id: str
    name: str
    description: str | None = None
    tags: List[str] | None = None
    examples: List[str] | None = None
    inputModes: List[str] | None = None
    outputModes: List[str] | None = None
```

### Error Handling

Implement robust error handling:

```python
try:
    response = await client.send_task(payload)
except A2AClientHTTPError as e:
    # Handle HTTP errors
    print(f"HTTP Error: {e.status_code} - {e.message}")
except A2AClientJSONError as e:
    # Handle JSON parsing errors
    print(f"JSON Error: {e.message}")
```

### Authentication

Implement different authentication schemes:

```python
if agent_card.authentication.schemes[0].lower() == "bearer":
    self.auth_header = f"Bearer {auth}"
elif agent_card.authentication.schemes[0].lower() == "basic":
    encoded_auth = base64.b64encode(auth.encode()).decode()
    self.auth_header = f"Basic {encoded_auth}"
```

## Lab 10: Deployment and Production

### Docker Deployment

Each agent can be containerized:

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY pyproject.toml uv.lock ./
RUN pip install uv && uv sync --frozen
COPY . .
CMD ["uv", "run", "."]
```

### Environment Configuration

Use production environment variables:

```env
GOOGLE_CLOUD_PROJECT=your-production-project
GCLOUD_LOCATION=us-central1
SCHOLAR_AGENT_URL=https://scholar-agent.run.app
TEACHER_AGENT_URL=https://teacher-agent.run.app
```

### Scaling Considerations

1. **Load Balancing**: Multiple instances of each agent
2. **Session Management**: Distributed session storage
3. **Monitoring**: Health checks and metrics collection
4. **Security**: Proper authentication and authorization

## Conclusion

You've successfully built a distributed AI agent system using the A2A protocol! Key takeaways:

1. **Agent Specialization**: Each agent focuses on specific capabilities
2. **Protocol Standardization**: A2A enables interoperability
3. **Async Communication**: Non-blocking operations for scalability
4. **Structured Data**: Pydantic models ensure data integrity
5. **Error Handling**: Robust error management across the system

### Next Steps

1. **Add More Agents**: Create specialized agents for different domains
2. **Implement Streaming**: Real-time response streaming
3. **Add Persistence**: Database integration for session management
4. **Monitoring**: Comprehensive logging and metrics
5. **Security**: Advanced authentication and authorization

### Additional Resources

- [Google ADK Documentation](https://developers.google.com/agent-development-kit)
- [LangGraph Documentation](https://langchain-ai.github.io/langgraph/)
- [A2A Protocol Specification](https://developers.google.com/agent-to-agent)
- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)
