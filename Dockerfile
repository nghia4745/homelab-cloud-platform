FROM python:3.11-slim AS builder

WORKDIR /build

COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt
# packages installed under /root/.local

FROM python:3.11-slim AS runtime

RUN useradd -m -u 1000 appuser

WORKDIR /app

COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local
COPY app/main.py .

ENV PATH=/home/appuser/.local/bin:$PATH \
  PYTHONUNBUFFERED=1

USER appuser

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "main:app"]
