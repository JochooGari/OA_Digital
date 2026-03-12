FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/
COPY docs/ ./docs/

# Cloud Run Job mode (batch): run main.py directly
# Dashboard mode: uvicorn src.api:app --host 0.0.0.0 --port $PORT
CMD ["python", "src/main.py"]
