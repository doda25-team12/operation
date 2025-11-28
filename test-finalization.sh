#!/bin/bash
# Pre-flight checks for finalization playbook

echo "=========================================="
echo "Pre-flight Checks for Finalization"
echo "=========================================="
echo ""

# Check 1: VMs are running
echo "1. Checking Vagrant VMs..."
vagrant status | grep -E "ctrl|node-"
echo ""

# Check 2: Controller is accessible
echo "2. Checking controller accessibility..."
if ping -c 2 192.168.56.100 > /dev/null 2>&1; then
    echo "✓ Controller is reachable at 192.168.56.100"
else
    echo "✗ Controller is NOT reachable at 192.168.56.100"
    exit 1
fi
echo ""

# Check 3: Kubeconfig exists
echo "3. Checking kubeconfig..."
if [ -f kubeconfig ]; then
    echo "✓ kubeconfig file exists"
    export KUBECONFIG=./kubeconfig
else
    echo "✗ kubeconfig file not found"
    exit 1
fi
echo ""

# Check 4: Kubernetes cluster is responding
echo "4. Checking Kubernetes cluster..."
if kubectl cluster-info > /dev/null 2>&1; then
    echo "✓ Kubernetes cluster is responding"
    kubectl get nodes
else
    echo "✗ Cannot connect to Kubernetes cluster"
    exit 1
fi
echo ""

# Check 5: SSH access to controller
echo "5. Checking SSH access..."
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no vagrant@192.168.56.100 "echo 'SSH OK'" 2>/dev/null | grep -q "SSH OK"; then
    echo "✓ SSH access to controller works"
else
    echo "✗ SSH access to controller failed"
    echo "  Make sure SSH keys are properly configured"
    exit 1
fi
echo ""

echo "=========================================="
echo "All pre-flight checks passed!"
echo "Ready to run finalization playbook:"
echo ""
echo "  ansible-playbook -u vagrant -i 192.168.56.100, ansible/playbooks/finalization.yml"
echo "=========================================="
