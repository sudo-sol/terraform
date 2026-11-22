## Dependency builder
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt

## Runtime image
FROM python:3.12-slim AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=9999

COPY --from=builder /install /usr/local

WORKDIR /app
COPY app.py .

# Run as a non-root user — principle of least privilege
RUN addgroup --system appgroup \
 && adduser  --system --ingroup appgroup --no-create-home appuser
USER appuser

EXPOSE ${PORT}

# gunicorn with 2 workers:
#   - Fargate tasks are typically single-vCPU; 2 workers handle brief concurrency
#     during the /load endpoint without over-provisioning.
#   - --timeout 120 gives the /load endpoint up to 2 min before gunicorn kills it.
#   - --access-logfile - streams access logs to stdout → CloudWatch Logs via awslogs driver.
CMD ["sh", "-c", \
     "gunicorn app:app \
      --bind 0.0.0.0:${PORT} \
      --workers 2 \
      --timeout 120 \
      --access-logfile - \
      --error-logfile -"]
