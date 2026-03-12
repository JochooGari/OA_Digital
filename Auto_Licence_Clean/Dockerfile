# =============================================================
# Auto-Clean Licences Pro — Cloud Run Job
# BTDP naming: autoclean-gcr-main-ew1-{env}
# =============================================================

FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./

# Cloud Run Job: run main.py (not a web server)
# For API/dashboard mode, override with: CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8080"]
CMD ["python", "main.py"]
