# Assessment 1

## Week 2

- Atharva Dagaonkar (6406947): Completed splitting the SMS checker repository (F0). Worked on Automated training with GitHub actions (F9). PR Links:        <https://github.com/doda25-team12/operation/pull/2>, <https://github.com/doda25-team12/model-service/pull/1>, <https://github.com/doda25-team12/model-service/pull/9>
- Yuvraj Singh Pathania (6495044) : Worked on automating the container image release and making the containers flexible with the exposed ports. Added environment configuration for service ports in model-service Dockerfile and serve_model.py. Added environment configuration variables in app Dockerfile and FrontendController.
  - PR Links: <https://github.com/doda25-team12/model-service/pull/8>, <https://github.com/doda25-team12/model-service/pull/3>, <https://github.com/doda25-team12/app/pull/4>, <https://github.com/doda25-team12/app/pull/3>
- Maksym Ziemlewski (5530458): Created a Version-aware Library (f1) and f7: Docker Compose Operation.
PR Links:
F1: <https://github.com/doda25-team12/lib-version/pull/1>
<https://github.com/doda25-team12/app/pull/2>
F7: <https://github.com/doda25-team12/operation/pull/1>
- Stilyan Penchev (5749131): Worked and completeted The multi-stage and multi-architecture tasks.
PR Links: <https://github.com/doda25-team12/model-service/pull/6>,
- Dragos Erhan (6450520): Worked and created the Dockerfile for frontend and backend and also make the dynamic version of the model. PR Links: <https://github.com/doda25-team12/app/pull/1>, <https://github.com/doda25-team12/model-service/pull/2>
- Andrei Paduraru (5775589): F2+F11
PR Link: <https://github.com/doda25-team12/lib-version/pull/3/commits>

## Week 3

- Atharva Dagaonkar (6406947): Completed basic VM setup, networking, forwarding, setup of Kubernetes controller and helm installation (Step 1 - 17). Installed Kubernetes dashboard, ingress, metalLB and Istio. (Steps 20-23). PR Links: <https://github.com/doda25-team12/operation/pull/3>, <https://github.com/doda25-team12/operation/pull/5>
- Yuvraj Singh Pathania (6495044) : Worked on setting up the kubernetes workers (Section 1.3, Steps 18-19): implemented worker node join automation in node.yaml using kubeadm token delegation, fixed SSH keys path in general.yaml, added SSH public key for team requirement, and verified successful cluster join for all worker nodes

  - PR Link : <https://github.com/doda25-team12/operation/pull/4>

- Maksym Ziemlewski (5530458): Cooperated in setting up step 1.4, Finalizing the Cluster Setup
- Stilyan Penchev (5749131): I worked with Andrei on 1.4. We did encounter a lot of issues connected to the WSL setup.
- Erhan Dragos (6450520): Worked with on solving 1.4. However, ansible did had issues with wsl. And while trying to figure out how to solve the issue, the task was already finished.
- Andrei Paduraru (5774489): I mainly worked on troubleshooting and finding solutions for Windows users.

## Week 4

- Atharva Dagaonkar (6406947): Worked on migration from Docker to Kubernetes. PR Link: <https://github.com/doda25-team12/operation/pull/6>
- Yuvraj Singh Pathania (6495044) : Worked on setting up prometheus and adding metrics endpoint to model service
  - PR Link 1: <https://github.com/doda25-team12/operation/pull/8>
  - PR Link 2: <https://github.com/doda25-team12/model-service/pull/10>
- Andrei Paduraru (5774489): Bug fixing for AMD64 processors. PR Link: <https://github.com/doda25-team12/operation/pull/7>
- Stilyan Penchev (5749131): Installed and setup linux on my personal computer to make running the project possible.
- Dragos Erhan (6450520): Imlemented Alerting with this PR: <https://github.com/doda25-team12/operation/pull/15>. Moreover working on the Grafana Task.

## Week 5

- Atharva Dagaonkar (6406947): Worked on fixing the Vagrantfile and assisted in debugging <https://github.com/doda25-team12/operation/pull/14>
- Yuvraj Singh Pathania(6495044): Implemented Istio traffic management for A4 assignment: Gateway/VirtualService/DestinationRules with 90/10 canary routing and sticky sessions. Created canary deployments and deployment documentation.
  - PR Link : <https://github.com/doda25-team12/operation/pull/13>
- Stilyan Penchev (5749131): (Assignment A3) I added ServiceMonitor helm chart template to make implementing alerting with Prometheus easier.
PR Link: <https://github.com/doda25-team12/operation/pull/11>
- Andrei Paduraru (5774489): More bugfixing for Ubuntu. PR: <https://github.com/doda25-team12/operation/pull/12>
- Dragos Erhan (6450520): Continue working on Grafana+ Continuous Experimentation Task with Atharva.

## Week 6

- Atharva Dagaonkar (6406947): Helped in general debugging and solidified Vagrant configuration.
- Stilyan Penchev (5749131): (Assignment A4) Added simple global rate limiting with a cap of 10 requests per minute. PR: <https://github.com/doda25-team12/operation/pull/18>
- Andrei Paduraru (5774489): Bugifixing docker and updating README:
  - <https://github.com/doda25-team12/operation/pull/19>
  - <https://github.com/doda25-team12/model-service/pull/12>
  - <https://github.com/doda25-team12/app/pull/5>
- Yuvraj Singh Pathania (6495044) : Tested out current progress by setting up the entire project locally and made sure things are good to go before the peer review

## Week 7

- Atharva Dagaonkar (6406947): (A4 Extension Proposal) Designed and implemented Configuration Validation Framework with 6-layer validation system (JSON schema, port consistency, image tag coherence, version labels, ConfigMap completeness, environment variables). Created validation scripts (validate-config.sh, pre-deployment-check.sh), JSON schema for values.yaml, and test suite with 3 test cases. Fixed critical bug: added MODEL_VERSION injection to ConfigMap template preventing CrashLoopBackOff errors. PR: <https://github.com/doda25-team12/operation/pull/25>
- Yuvraj Singh Pathania (6495044): Implemented Additional Use Case for Istio by implementing shadow launch for model-service including shadow deployment template, traffic mirroring and documentation updates. PR: <https://github.com/doda25-team12/operation/pull/21>
- Stilyan Penchev (5749131): (A4) Added improvments to the late rimiting from the previous week. Namely ingress rate-limiting knobs for rps, connections and status code. PR: <https://github.com/doda25-team12/operation/pull/20>

## Week 8

- Atharva Dagaonkar (6406947): (A4 Extension Proposal) Completed Configuration Validation Framework implementation. Integrated GitHub Actions CI/CD workflow for automated PR validation. Created comprehensive documentation (EXTENSION_PROPOSAL.md) including usage guide, verification steps, troubleshooting, and rollout strategy. Fixed Helm chart defaults (disabled CRD-dependent features) and template reference errors. Branch: feature/configuration-validation-framework, PR: <https://github.com/doda25-team12/operation/pull/25>
- Yuvraj Singh Pathania (6495044): For model-service - Implemented production-standard code linting using Ruff. Added lint checks to train-release and release-container CI/CD pipelines. Fixed 126 linting errors and resolved pickle deserialization bug caused by removed imports.
  - PR Link : <https://github.com/doda25-team12/model-service/pull/13>

## Week 9
- Atharva Dagaonkar (6406947): Fixed documentation issues in README.md - removed references to non-existent local-setup.sh and LOCAL-SETUP.md, corrected Docker image name from app-service to app, removed duplicate content, fixed broken markdown links. Added MODEL_VERSION injection to Kubernetes model-service deployments (stable, canary, shadow) to prevent CrashLoopBackOff errors. Updated API test command to use working Python alternative.
- Yuvraj Singh Pathania (6495044): Fixed environment variables for GHCR image pull in docker-compose.yml and .env configuration files. Fixed model access path in model-service serve_model.py to properly handle model file paths.
  - PR Link: <https://github.com/doda25-team12/model-service/pull/14>
- Stilyan Penchev (5749131): Implemented kubernetes connectivity check to the ansible finalization playbook. PR: <https://github.com/doda25-team12/operation/pull/30>
