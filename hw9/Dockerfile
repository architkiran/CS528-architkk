FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    google-cloud-storage \
    google-cloud-logging \
    requests

COPY server.py .

ENV PORT=8080
ENV BUCKET_NAME=bu-cs528-architkk

EXPOSE 8080

CMD ["python3", "server.py"]
