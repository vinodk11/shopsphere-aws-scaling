# Stage 9 secrets

No secret values are committed to Git.

The application pipeline creates `shopsphere-db-credentials` from the Jenkins credential
`shopsphere-db-password` at deployment time. Prefer replacing this with AWS Secrets Manager
+ External Secrets/Secrets Store CSI when that integration is introduced.
