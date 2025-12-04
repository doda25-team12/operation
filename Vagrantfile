# -*- mode: ruby -*-
# vi: set ft=ruby :

# ============================================
# CONFIGURATION VARIABLES
# ============================================
NUM_WORKERS = 2                    # Number of worker nodes (configurable)
CTRL_CPU = 2                      # CPU cores for controller
CTRL_MEMORY = 4096                 # Memory (MB) for controller
WORKER_CPU = 2                     # CPU cores per worker
WORKER_MEMORY = 6144               # Memory (MB) per worker

# Network Configuration
NETWORK_PREFIX = "192.168.56"      # Host-only network prefix
CTRL_IP = "#{NETWORK_PREFIX}.100"  # Controller IP
WORKER_IP_START = 101              # Workers start at .101

# Base box
BOX_IMAGE = "bento/ubuntu-24.04"

# Shared folder configuration for model storage
SHARED_FOLDER_HOST = "./k8s-models"      # Host path (relative to Vagrantfile)
SHARED_FOLDER_GUEST = "/mnt/shared-models"  # Guest path (mounted in VMs)

# ============================================
# VAGRANT CONFIGURATION
# ============================================
Vagrant.configure("2") do |config|
  
  # Common settings for all VMs
  config.vm.box = BOX_IMAGE
  config.vm.box_check_update = false

  # SSH settings
  config.ssh.insert_key = false

  # ==========================================
  # CONTROLLER NODE
  # ==========================================
  config.vm.define "ctrl", primary: true do |ctrl|
    ctrl.vm.hostname = "ctrl"

    # Host-only network with fixed IP
    ctrl.vm.network "private_network", ip: CTRL_IP

    # Shared folder for model storage
    ctrl.vm.synced_folder SHARED_FOLDER_HOST, SHARED_FOLDER_GUEST, create: true
    
    # VirtualBox provider settings
    ctrl.vm.provider "virtualbox" do |vb|
      vb.name = "k8s-ctrl"
      vb.memory = CTRL_MEMORY
      vb.cpus = CTRL_CPU
      vb.gui = false
      
      # Performance optimizations
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end

    # Ansible provisioner for controller
    ctrl.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/playbooks/general.yaml"
      ansible.extra_vars = {
        node_ip: CTRL_IP,
        num_workers: NUM_WORKERS,
        network_prefix: NETWORK_PREFIX,
        worker_ip_start: WORKER_IP_START
      }
    end

    ctrl.vm.provision "ansible" do |ansible|
      ansible.playbook = "ansible/playbooks/ctrl.yaml"
      ansible.extra_vars = {
        node_ip: CTRL_IP,
        num_workers: NUM_WORKERS,
        network_prefix: NETWORK_PREFIX,
        worker_ip_start: WORKER_IP_START
      }
    end
  end

  # ==========================================
  # WORKER NODES
  # ==========================================
  (1..NUM_WORKERS).each do |i|
    config.vm.define "node-#{i}" do |node|
      node.vm.hostname = "node-#{i}"

      # Calculate worker IP using template arithmetic
      worker_ip = "#{NETWORK_PREFIX}.#{WORKER_IP_START + i - 1}"

      # Host-only network with fixed IP
      node.vm.network "private_network", ip: worker_ip

      # Shared folder for model storage
      node.vm.synced_folder SHARED_FOLDER_HOST, SHARED_FOLDER_GUEST, create: true
      
      # VirtualBox provider settings
      node.vm.provider "virtualbox" do |vb|
        vb.name = "k8s-node-#{i}"
        vb.memory = WORKER_MEMORY
        vb.cpus = WORKER_CPU
        vb.gui = false
        
        # Performance optimizations
        vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
        vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      end

      # Ansible provisioner for worker nodes
      node.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/playbooks/general.yaml"
        ansible.extra_vars = {
          node_ip: worker_ip,
          num_workers: NUM_WORKERS,
          network_prefix: NETWORK_PREFIX,
          worker_ip_start: WORKER_IP_START
        }
      end

      node.vm.provision "ansible" do |ansible|
        ansible.playbook = "ansible/playbooks/node.yaml"
        ansible.extra_vars = {
          node_ip: worker_ip,
          ctrl_ip: CTRL_IP,
          num_workers: NUM_WORKERS,
          network_prefix: NETWORK_PREFIX,
          worker_ip_start: WORKER_IP_START
        }
      end
    end
  end

end