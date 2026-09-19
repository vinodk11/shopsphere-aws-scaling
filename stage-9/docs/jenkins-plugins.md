# Jenkins plugins used by Stage 9 v2

Required/recommended:

- Pipeline / Declarative Pipeline
- Git / GitHub Branch Source
- Pipeline: AWS Steps (`pipeline-aws`) — AWS credential context, ECR integration
- Docker Pipeline (`docker-workflow`) — `docker.build`, `docker.withRegistry`, image push
- Amazon ECR plugin (`amazon-ecr`) — ECR registry credential provider
- NodeJS (`nodejs`) — managed Node/npm runtime
- Kubernetes (`kubernetes`) — optional dynamic agents
- Kubernetes CLI (`kubernetes-cli`) — `withKubeConfig`
- Credentials Binding (`credentials-binding`)
- Pipeline Utility Steps (`pipeline-utility-steps`)
- Warnings Next Generation (`warnings-ng`) — publish Trivy/other reports
- OWASP Dependency-Check (`dependency-check-jenkins-plugin`) if used for SCA
- SonarQube Scanner (`sonar`) if SonarQube is enabled
- GitHub Checks (`github-checks`) if Jenkins should publish checks to GitHub

Notes:
- There is no maintained first-party Jenkins Pipeline step that covers every AWS ELBv2 listener-rule mutation. Stage 9 therefore uses `withAWS` from Pipeline: AWS Steps and a small direct `aws elbv2` CLI invocation for traffic-weight changes. No project bash migration scripts are used.
- The old Official OWASP ZAP Jenkins plugin currently has an unresolved security warning about credentials stored in plaintext. Do not install it for this pipeline; run ZAP from a pinned container/tool instead.
- Copy Artifact (`copyartifact`) — imports the successful infrastructure output artifact.
- Pipeline: Build Step (`pipeline-build-step`) — the application pipeline can request a controlled traffic-weight change from the infrastructure pipeline rather than mutating the ALB directly.
