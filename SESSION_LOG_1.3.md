# Session Log: Section 1.3 - Setting up Kubernetes Workers

**Date:** November 28, 2025  
**Contributor:** Yuvraj Singh Pathania  
**Section:** 1.3 Setting up Kubernetes Workers (Steps 18-19)

---

## Overview

I verified and tested the implementation of Section 1.3 (Kubernetes Worker Node Setup) from Assignment A2. The `node.yaml` playbook was already implemented correctly. Verified its functionality and fixed a related SSH keys path issue.

---

## Commands Executed

### 1. Initial Setup & Environment Check

```bash
# Check VM status
cd ./operation && vagrant status
# Output: ctrl, node-1, node-2 - all "not created"

# Check if Ansible is installed
which ansible
# Output: ansible not found

# Activate conda environment with Ansible
conda activate doda-class-experiments

# Verify Ansible installation
which ansible && ansible --version
# Output: ansible [core 2.20.0]
```

### 2. Provisioning the Cluster

```bash
# Clean up any partially created VMs
vagrant destroy -f

# Provision all VMs (controller + 2 workers)
vagrant up
```

**What this does:**
- Creates 3 VMs: `ctrl` (192.168.56.100), `node-1` (192.168.56.101), `node-2` (192.168.56.102)
- Runs `general.yaml` on all VMs (installs K8s tools, containerd, etc.)
- Runs `ctrl.yaml` on controller (initializes cluster, installs Flannel, Helm)
- Runs `node.yaml` on workers (joins workers to cluster)

### 3. Verifying Cluster Status

```bash
# SSH into controller and check nodes
vagrant ssh ctrl -c "kubectl get nodes -o wide"
```

**Output:**
```
NAME     STATUS   ROLES           AGE     VERSION   INTERNAL-IP      
ctrl     Ready    control-plane   5m30s   v1.32.4   192.168.56.100
node-1   Ready    <none>          3m50s   v1.32.4   192.168.56.101
node-2   Ready    <none>          2m37s   v1.32.4   192.168.56.102
```

### 4. Fetching Kubeconfig to Host

```bash
# Copy kubeconfig from controller to host
vagrant ssh ctrl -c "cat /home/vagrant/.kube/config" > kubeconfig
```

### 5. Verifying Flannel Pod Network

```bash
vagrant ssh ctrl -c "kubectl get pods -n kube-flannel"
```

**Output:**
```
NAME                    READY   STATUS    RESTARTS   AGE
kube-flannel-ds-449rr   1/1     Running   0          15m
kube-flannel-ds-gn4rl   1/1     Running   0          16m
kube-flannel-ds-p58xl   1/1     Running   0          14m
```

### 6. Verifying Control Plane Pods

```bash
vagrant ssh ctrl -c "kubectl get pods -n kube-system"
```

**Output:**
```
NAME                           READY   STATUS    RESTARTS   AGE
coredns-668d6bf9bc-2ndvs       1/1     Running   0          9m53s
coredns-668d6bf9bc-d9sfw       1/1     Running   0          9m53s
etcd-ctrl                      1/1     Running   0          10m
kube-apiserver-ctrl            1/1     Running   0          10m
kube-controller-manager-ctrl   1/1     Running   0          10m
kube-proxy-2tc56               1/1     Running   0          8m22s
kube-proxy-c58zp               1/1     Running   0          9m53s
kube-proxy-gjl7f               1/1     Running   0          7m9s
kube-scheduler-ctrl            1/1     Running   0          10m
```

---

## Fixes Applied

### Fix 1: SSH Keys Path in `general.yaml`

**Problem:** SSH key registration was being skipped with warning:
```
[WARNING]: Unable to find '../../../ssh-keys' in expected paths
```

**Solution:** Changed the path from `../../../ssh-keys` to `../../ssh-keys`

**File:** `ansible/playbooks/general.yaml` (line 24)

```yaml
# Before (incorrect - too many levels up)
ssh_keys_path: "../../../ssh-keys"

# After (correct - 2 levels up from ansible/playbooks/)
ssh_keys_path: "../../ssh-keys"
```

### Fix 2: Added Second SSH Key

**Requirement:** Rubric requires at least 2 team member SSH keys

**Command:**
```bash
cp ~/.ssh/id_ed25519.pub ./operation/ssh-keys/yuvraj-pathania.pub
```

**Result:** `ssh-keys/` now contains:
- `atharva-dagaonkar.pub`
- `yuvraj-pathania.pub`

### Re-provision to Apply SSH Key Changes

```bash
vagrant provision --provision-with ansible
```

### Verify SSH Keys Registered

```bash
vagrant ssh ctrl -c "cat ~/.ssh/authorized_keys"
```

**Output confirmed both team keys are registered.**

---

## Section 1.3 Implementation Details

### node.yaml - How Worker Nodes Join the Cluster

The `node.yaml` playbook implements Steps 18-19 from the assignment:

**Step 18: Generate Join Command**
```yaml
- name: Generate join command on controller
  shell: kubeadm token create --print-join-command
  delegate_to: ctrl           # Run on controller, not the worker
  delegate_facts: true
  register: join_command      # Store output in variable
  when: not kubelet_conf.stat.exists
```

**Step 19: Run Join Command**
```yaml
- name: Join worker node to the cluster
  command: "{{ join_command.stdout }}"
  when: not kubelet_conf.stat.exists
```

**Idempotency Check:**
```yaml
- name: Check if node has already joined the cluster
  stat:
    path: /etc/kubernetes/kubelet.conf
  register: kubelet_conf
```

This prevents re-joining if the node is already part of the cluster.

---

## Final Cluster State

| Component | Status |
|-----------|--------|
| ctrl (control-plane) | Ready |
| node-1 (worker) | Ready |
| node-2 (worker) | Ready |
| Flannel CNI | Running (3 pods) |
| CoreDNS | Running (2 pods) |
| kube-proxy | Running (3 pods) |
| SSH Keys | 2 registered |

---

## Files Modified

1. `ansible/playbooks/general.yaml` - Fixed SSH keys path
2. `ssh-keys/yuvraj-pathania.pub` - Added new SSH public key

## Files Verified (No Changes Needed)

1. `ansible/playbooks/node.yaml` - Already correctly implements Steps 18-19
2. `ansible/playbooks/ctrl.yaml` - Controller setup working correctly
3. `Vagrantfile` - VM configuration correct

