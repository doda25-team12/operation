#!/bin/bash
# Setup script for VirtualBox shared folder storage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OPERATION_DIR="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$OPERATION_DIR/k8s-models"

echo "=========================================="
echo "SMS Checker - Shared Storage Setup"
echo "=========================================="
echo

# Create the k8s-models directory if it doesn't exist
if [ ! -d "$MODELS_DIR" ]; then
    echo "Creating k8s-models directory..."
    mkdir -p "$MODELS_DIR"
    echo "✓ Created $MODELS_DIR"
else
    echo "✓ k8s-models directory already exists"
fi

# Check if models exist in the parent models/ directory
PARENT_MODELS_DIR="$OPERATION_DIR/models"
if [ -d "$PARENT_MODELS_DIR" ] && [ "$(ls -A "$PARENT_MODELS_DIR" 2>/dev/null)" ]; then
    echo
    echo "Found existing models in $PARENT_MODELS_DIR"
    read -p "Copy models to k8s-models directory? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp -v "$PARENT_MODELS_DIR"/* "$MODELS_DIR/" || true
        echo "✓ Models copied successfully"
    fi
fi

# Check if model files exist
MODEL_COUNT=$(find "$MODELS_DIR" -name "*.joblib" 2>/dev/null | wc -l)
if [ "$MODEL_COUNT" -eq 0 ]; then
    echo
    echo "⚠️  No model files found in $MODELS_DIR"
    echo
    echo "You need to train the model or copy model files to this directory."
    echo "Expected files:"
    echo "  - model-<VERSION>.joblib"
    echo "  - preprocessor.joblib"
    echo
    echo "To train the model, follow the instructions in model-service/README.md"
    echo "or copy pre-trained models to: $MODELS_DIR"
else
    echo
    echo "✓ Found $MODEL_COUNT model file(s):"
    find "$MODELS_DIR" -name "*.joblib" -exec basename {} \;
fi

echo
echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo "1. Ensure model files are in: $MODELS_DIR"
echo "2. Start Vagrant cluster: vagrant up"
echo "3. The shared folder will be mounted at: /mnt/shared-models"
echo "4. Deploy using kubectl or Helm"
echo
