# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM python:3.13-slim
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

ADD . /app
WORKDIR /app

RUN uv sync --frozen

EXPOSE 8080

ENV PYTHONUNBUFFERED=1
ENV GOOGLE_GENAI_USE_VERTEXAI=True
ENV GOOGLE_CLOUD_PROJECT=amaraj-development
ENV GOOGLE_CLOUD_LOCATION=us-central1
ENV SCHOLAR_AGENT_AUTH=pizza123
ENV SCHOLAR_AGENT_URL=https://scholar-agent-795845071313.us-central1.run.app
ENV TEACHER_AGENT_AUTH=pizza123
ENV TEACHER_AGENT_URL=https://teacher-agent-795845071313.us-central1.run.app

ENTRYPOINT ["uv", "run", "researcher_demo.py"]
