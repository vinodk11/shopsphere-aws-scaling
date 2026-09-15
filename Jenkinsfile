pipeline {
    agent any

    parameters {
        choice(
            name: 'STAGE',
            choices: ['stage-1', 'stage-2', 'stage-3', 'stage-4', 'stage-5', 'stage-6', 'stage-7', 'stage-8'],
            description: 'Select ShopSphere stage (stage-1 = Monolith, stage-2 = EC2 + RDS, stage-3 = ALB + ASG, stage-4 = Redis, stage-5 = SQS + Lambda, stage-6 = CloudFront + WAF, stage-7 = DevSecOps, stage-8 = Docker)'
        )
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply', 'destroy'],
            description: 'Terraform action'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip manual confirmation before apply or destroy'
        )
    }

    environment {
        TF_IN_AUTOMATION = 'true'
        TF_DIR           = "${params.STAGE}/terraform"
        TF_IMAGE         = 'hashicorp/terraform:latest'
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        ansiColor('xterm')
    }

    stages {

        stage('Checkout SCM') {
            steps {
                echo "🚀 Checking out ShopSphere repository for ${params.STAGE}..."
                git branch: 'main', url: 'https://github.com/vinodk11/shopsphere-aws-scaling.git'
            }
        }

        stage('Terraform Init & Validate') {
            steps {
                echo "🔧 Running terraform init & validate via Docker container..."
                sh """
                    docker run --rm \
                        -v \$(pwd):/workspace \
                        -w /workspace/${env.TF_DIR} \
                        --net=host \
                        ${env.TF_IMAGE} version

                    docker run --rm \
                        -v \$(pwd):/workspace \
                        -w /workspace/${env.TF_DIR} \
                        --net=host \
                        ${env.TF_IMAGE} init -input=false

                    docker run --rm \
                        -v \$(pwd):/workspace \
                        -w /workspace/${env.TF_DIR} \
                        --net=host \
                        ${env.TF_IMAGE} validate
                """
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    if (params.ACTION == 'destroy') {
                        echo "⚠️ Generating DESTROY plan for ${params.STAGE}..."
                        sh """
                            docker run --rm \
                                -v \$(pwd):/workspace \
                                -w /workspace/${env.TF_DIR} \
                                --net=host \
                                ${env.TF_IMAGE} plan -destroy -out=tfplan -input=false
                        """
                    } else {
                        echo "📋 Generating execution plan for ${params.STAGE}..."
                        sh """
                            docker run --rm \
                                -v \$(pwd):/workspace \
                                -w /workspace/${env.TF_DIR} \
                                --net=host \
                                ${env.TF_IMAGE} plan -out=tfplan -input=false
                        """
                    }
                }
            }
        }

        stage('Approval Gate') {
            when {
                expression { 
                    return (params.ACTION == 'apply' || params.ACTION == 'destroy') && !params.AUTO_APPROVE 
                }
            }
            steps {
                script {
                    def actionText = params.ACTION == 'destroy' ? 'DESTROY' : 'APPLY'
                    input(
                        id: 'TerraformApproval',
                        message: "Review the plan above. Proceed with Terraform ${actionText} on ${params.STAGE}?",
                        ok: "Proceed with ${actionText}"
                    )
                }
            }
        }

        stage('Terraform Apply / Destroy') {
            when {
                expression { return params.ACTION == 'apply' || params.ACTION == 'destroy' }
            }
            steps {
                script {
                    if (params.ACTION == 'apply') {
                        echo "🚀 Applying ${params.STAGE} infrastructure via Docker..."
                        sh """
                            docker run --rm \
                                -v \$(pwd):/workspace \
                                -w /workspace/${env.TF_DIR} \
                                --net=host \
                                ${env.TF_IMAGE} apply -input=false tfplan
                        """
                    } else if (params.ACTION == 'destroy') {
                        echo "💥 Destroying ${params.STAGE} infrastructure via Docker..."
                        sh """
                            docker run --rm \
                                -v \$(pwd):/workspace \
                                -w /workspace/${env.TF_DIR} \
                                --net=host \
                                ${env.TF_IMAGE} apply -input=false tfplan
                        """
                    }
                }
            }
        }

        stage('Smoke Test & Health Verification') {
            when {
                expression { return params.ACTION == 'apply' }
            }
            steps {
                dir("${env.TF_DIR}") {
                    echo "🩺 Verifying ShopSphere Storefront Health endpoint..."
                    sh '''
                        CF_DOMAIN=$(grep -o '"cloudfront_domain_name": *"[^"]*"' terraform.tfstate | head -n1 | cut -d '"' -f4 || true)
                        ALB_DNS=$(grep -o '"alb_dns_name": *"[^"]*"' terraform.tfstate | head -n1 | cut -d '"' -f4 || true)
                        EC2_IP=$(grep -o '"public_ip": *"[^"]*"' terraform.tfstate | head -n1 | cut -d '"' -f4 || true)

                        if [ -n "$CF_DOMAIN" ]; then
                            HEALTH_URL="https://${CF_DOMAIN}/health"
                        elif [ -n "$ALB_DNS" ]; then
                            HEALTH_URL="http://${ALB_DNS}/health"
                        elif [ -n "$EC2_IP" ]; then
                            HEALTH_URL="http://${EC2_IP}/health"
                        else
                            echo "⚠️ Could not parse endpoint (CloudFront, ALB DNS or EC2 IP) from state, skipping health test."
                            exit 0
                        fi
                        echo "Target Health Check: $HEALTH_URL"
                        echo "Waiting for instance bootstrap and health endpoint to be ready..."

                        ATTEMPTS=0
                        MAX_ATTEMPTS=20
                        SUCCESS=0

                        until [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; do
                            RES=$(curl -s "$HEALTH_URL" || true)
                            if echo "$RES" | grep -q '"status":"UP"'; then
                                echo "✅ Application is UP and healthy!"
                                echo "$RES"
                                SUCCESS=1
                                break
                            else
                                echo "⏳ Attempt $((ATTEMPTS+1))/$MAX_ATTEMPTS: Waiting for instance bootstrap (15s)..."
                                sleep 15
                                ATTEMPTS=$((ATTEMPTS+1))
                            fi
                        done

                        if [ $SUCCESS -ne 1 ]; then
                            echo "❌ Health check timed out after 5 minutes."
                            exit 1
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            dir("${env.TF_DIR}") {
                sh 'rm -f tfplan'
            }
        }
        success {
            echo "🎉 ShopSphere ${params.STAGE.toUpperCase()} ${params.ACTION.toUpperCase()} completed successfully!"
        }
        failure {
            echo "❌ ShopSphere ${params.STAGE.toUpperCase()} Pipeline failed. Check console output."
        }
    }
}
