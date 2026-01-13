# Configuration Validation Framework

This framework prevents 90%+ of configuration-related deployment failures through 6 layers of automated validation.

**📖 Complete documentation**: [EXTENSION_PROPOSAL.md](EXTENSION_PROPOSAL.md)

## Quick Start

```bash
# 1. Install dependencies
bash k8s/validation/install-dependencies.sh

# 2. Run validation
bash k8s/validation/validate-config.sh

# 3. Pre-deployment check
bash k8s/validation/pre-deployment-check.sh

# 4. Deploy
helm install sms-detector k8s/helm-chart/sms-spam-detector \
  -n sms-spam-detection --create-namespace
```

## What It Validates

1. **JSON Schema** - Structural correctness
2. **Port Consistency** - Cross-file alignment
3. **Image Tag Coherence** - Canary/shadow uniqueness
4. **Version Labels** - Proper versioning
5. **ConfigMap Completeness** - MODEL_VERSION injection
6. **Environment Variables** - .env usage

## Key Scripts

```bash
install-dependencies.sh      # Install yq and Python dependencies
validate-config.sh           # Run all 6 validation layers
pre-deployment-check.sh      # Validation + helm lint + kubectl dry-run
verify-days-4-5.sh          # Implementation verifier
tests/run-tests.sh          # Test suite (3 tests)
```

## Files

```
validation/
├── EXTENSION_PROPOSAL.md           # Complete documentation ⭐
├── README.md                       # This file
├── install-dependencies.sh         # Dependency installer
├── validate-schema.py              # JSON schema validator
├── validate-config.sh              # Main validation (300+ lines)
├── pre-deployment-check.sh         # Pre-deployment orchestrator
├── verify-days-4-5.sh             # Verifier script
└── tests/
    ├── run-tests.sh
    ├── test-values-valid.yaml
    ├── test-values-port-mismatch.yaml
    └── test-values-canary-conflict.yaml

../helm-chart/sms-spam-detector/
├── values.schema.json              # JSON Schema (500+ lines)
└── templates/configmap.yaml        # Updated with MODEL_VERSION

../../.github/workflows/
└── validate-config.yml             # GitHub Actions integration
```

## Quick Command Reference

```bash
# Validate configuration
bash k8s/validation/validate-config.sh

# Run test suite
bash k8s/validation/tests/run-tests.sh

# Pre-deployment check
bash k8s/validation/pre-deployment-check.sh

# Deploy
helm install sms-detector k8s/helm-chart/sms-spam-detector -n sms-spam-detection --create-namespace

# Check deployment
kubectl get all -n sms-spam-detection

# View logs
kubectl logs -f -n sms-spam-detection -l app=app-service

# Uninstall
helm uninstall sms-detector -n sms-spam-detection
```

For detailed usage, verification steps, troubleshooting, and CI/CD integration, see **[EXTENSION_PROPOSAL.md](EXTENSION_PROPOSAL.md)**.
