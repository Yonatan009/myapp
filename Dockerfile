#STAGE 1
FROM python:3.11-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

#STAGE 2
FROM python:3.11-slim
WORKDIR /app
#Here we used builder from stage 1 to build anthoer image
COPY --from=builder /install /usr/local
COPY app.py .
EXPOSE 5001
CMD ["python", "app.py"]
