# SMS Checker - Operation Repository

This repository contains the orchestration configuration for running the SMS Checker application using Docker Compose. The SMS Checker is a distributed system for detecting spam in SMS messages, demonstrating a microservice architecture with a Java/Spring Boot frontend and a Python/Flask backend.

## System Architecture

The application consists of two microservices:

- **app-service** (Frontend): Spring Boot web application that provides a user interface for SMS spam detection
   - Exposes port 8080 to the host machine
   - Communicates with the model-service via internal Docker network
   - Source code: [doda25-team12/app](https://github.com/doda25-team12/app)

- **model-service** (Backend): Python/Flask REST API serving a machine learning model
   - Runs on internal port 8081 (not exposed to host)
   - Provides `/predict` endpoint for spam classification
   - Requires trained model files to be mounted or downloaded
   - Source code: [doda25-team12/model-service](https://github.com/doda25-team12/model-service)

## Prerequisites

1. **Docker Desktop**: Install from [docker.com](https://www.docker.com/)
2. **Model Files**: The model-service requires trained ML model files. You have two options:
   - **Option A (Volume Mount)**: Place model files in the `models/` directory (see "Preparing Model Files" below)
   - **Option B (Download)**: Configure `MODEL_VERSION` and `MODEL_BASE_URL` environment variables for automatic download

## Preparing Model Files

The model-service expects the following files:
- `model-{VERSION}.joblib` - Trained decision tree classifier
- `preprocessor.joblib` - Text preprocessing pipeline

### Training Models Locally

If you want to train models from scratch:

1. Clone the model-service repository:
   ```bash
   git clone https://github.com/doda25-team12/model-service.git
   cd model-service
   ```

2. Train using Docker (recommended):
   ```bash
   docker run -it --rm -v ./:/root/sms python:3.12.9-slim bash
   # Inside container:
   cd /root/sms
   pip install -r requirements.txt
   mkdir -p output
   python src/read_data.py
   python src/text_preprocessing.py
   python src/text_classification.py
   ```

3. Copy the generated `.joblib` files from `model-service/output/` to `operation/models/`:
   ```bash
   cp output/model.joblib ../operation/models/model-0.0.1.joblib
   cp output/preprocessor.joblib ../operation/models/
   ```

### Using Pre-trained Models

If pre-trained models are available from a release URL, configure the download in `.env`:
```bash
MODEL_VERSION=0.0.1
MODEL_BASE_URL=https://github.com/doda25-team12/model-service/releases/download
```

## Configuration

All configuration is managed through the `.env` file:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HOST_PORT` | Port exposed on host machine for web UI | 8080 | No |
| `APP_INTERNAL_PORT` | Internal port for app-service | 8080 | No |
| `MODEL_INTERNAL_PORT` | Internal port for model-service | 8081 | No |
| `ORG_NAME` | GitHub organization for container images | doda25-team12 | Yes |
| `VERSION` | Docker image tag to use | latest | Yes |
| `MODEL_VERSION` | Model version for file naming | - | Yes (if using download) |
| `MODEL_BASE_URL` | Base URL for downloading model files | - | Yes (if using download) |

### Customizing Ports

If port 8080 is already in use on your machine, modify `HOST_PORT` in `.env`:
```bash
HOST_PORT=9090
```

## How to Run

1. **Navigate to the operation directory**:
   ```bash
   cd operation
   ```

2. **Ensure model files are available** (see "Preparing Model Files" section above)

3. **Start the application**:
   ```bash
   docker compose up -d
   ```

4. **Verify services are running**:
   ```bash
   docker compose ps
   ```

   Expected output:
   ```
   NAME                      STATUS
   operation-app-service-1   Up
   operation-model-service-1 Up
   ```

5. **Access the web interface**:
   Open your browser to [http://localhost:8080/sms](http://localhost:8080/sms)

6. **Stop the application**:
   ```bash
   docker compose down
   ```

## Verification and Testing

### Check Service Health

View logs to ensure services started correctly:
```bash
# View all logs
docker compose logs

# View specific service logs
docker compose logs app-service
docker compose logs model-service

# Follow logs in real-time
docker compose logs -f
```

### Test the Model Service API

While the model-service is not exposed to the host, you can test it via the app-service container:

```bash
docker compose exec app-service curl -X POST http://model-service:8081/predict \
  -H "Content-Type: application/json" \
  -d '{"sms": "Congratulations! You won a prize!"}'
```

Expected response:
```json
{
  "classifier": "decision tree",
  "result": "spam",
  "sms": "Congratulations! You won a prize!"
}
```

### Test the Web UI

1. Navigate to [http://localhost:8080/sms](http://localhost:8080/sms)
2. Enter an SMS message (e.g., "Win a free iPhone now!")
3. Click submit
4. Verify the classification result is displayed

## Troubleshooting

### Service fails to start

**Problem**: Model-service exits immediately

**Solution**: Check that model files are present:
```bash
ls -la models/
docker compose logs model-service
```

Ensure either:
- Model files exist in `models/` directory, OR
- `MODEL_VERSION` and `MODEL_BASE_URL` are set in `.env`

### Port conflict

**Problem**: Error "port is already allocated"

**Solution**: Change `HOST_PORT` in `.env` to an available port

### Cannot access web UI

**Problem**: Browser shows connection error

**Solution**:
1. Verify services are running: `docker compose ps`
2. Check logs: `docker compose logs app-service`
3. Ensure you're using the correct port from `.env`

### Model predictions fail

**Problem**: Frontend shows error when submitting SMS

**Solution**:
1. Check model-service logs: `docker compose logs model-service`
2. Verify model files are valid `.joblib` files
3. Ensure `MODEL_VERSION` matches the model filename

## Development and Maintenance

### Updating to Latest Images

To pull and use the latest container images:
```bash
docker compose pull
docker compose up -d
```

### Using Specific Versions

To run a specific release, update `.env`:
```bash
VERSION=v1.2.3
```

Then restart:
```bash
docker compose down
docker compose up -d
```

### Viewing Resource Usage

Monitor container resource consumption:
```bash
docker stats
```

## Additional Resources
- **Frontend Repository**: [doda25-team12/app](https://github.com/doda25-team12/app) - Spring Boot application source
- **Backend Repository**: [doda25-team12/model-service](https://github.com/doda25-team12/model-service) - ML model service source
- **Shared Library**: [doda25-team12/lib-version](https://github.com/doda25-team12/lib-version) - Version management
- **Docker Compose File**: [docker-compose.yml](./docker-compose.yml) - Service orchestration configuration
- **Environment Config**: [.env](./.env) - Configuration parameters

## Contributing

This operation repository should remain runnable with the latest image versions. When adding new infrastructure components (Vagrant, Ansible, Kubernetes, etc.), ensure backward compatibility with the Docker Compose deployment.
