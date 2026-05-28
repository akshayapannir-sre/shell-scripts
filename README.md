# Shell Scripts — SRE & Cloud Automation

> Bash and Python automation scripts for SRE and cloud operations,
> built from real day-to-day work managing AWS infrastructure and Kubernetes clusters.

---

## 📁 Structure

```
shell-scripts/
├── aws/
│   ├── ec2-cost-stopper.sh
│   ├── ecr-cleanup.sh
│   └── s3-bucket-audit.sh
├── kubernetes/
│   ├── pod-log-collector.sh
│   ├── namespace-resource-usage.sh
│   └── stuck-namespace-cleaner.sh
├── monitoring/
│   ├── disk-usage-alert.sh
│   └── process-monitor.sh
├── ci-cd/
│   ├── docker-cleanup.sh
│   └── jenkins-job-trigger.py
└── utils/
    ├── ssh-keygen-setup.sh
    └── bulk-tag-aws-resources.py
```

---

## ⚡ Scripts

| Script | Language | Use Case |
|---|---|---|
| [ec2-cost-stopper.sh](aws/ec2-cost-stopper.sh) | Bash | Auto-stop non-prod EC2s at night |
| [ecr-cleanup.sh](aws/ecr-cleanup.sh) | Bash | Remove untagged ECR images |
| [pod-log-collector.sh](kubernetes/pod-log-collector.sh) | Bash | Collect logs from all pods in namespace |
| [namespace-resource-usage.sh](kubernetes/namespace-resource-usage.sh) | Bash | CPU/memory usage per namespace |
| [stuck-namespace-cleaner.sh](kubernetes/stuck-namespace-cleaner.sh) | Bash | Force delete stuck terminating namespaces |
| [docker-cleanup.sh](ci-cd/docker-cleanup.sh) | Bash | Clean unused Docker images/containers |
| [disk-usage-alert.sh](monitoring/disk-usage-alert.sh) | Bash | Alert when disk usage exceeds threshold |

---

## 💡 Based On Real Automation

- Auto-stop non-prod EC2s saving cloud costs
- ECR cleanup preventing storage bloat
- Kubernetes namespace and pod management
- CI/CD pipeline automation with Jenkins
