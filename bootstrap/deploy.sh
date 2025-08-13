#!/bin/bash

# Load environment variables
. .env

# Check if the required environment variables are set
if [ -z "$ARGOCD_NAMESPACE" ] || [ -z "$MILVUS_NAMESPACE" ] || [ -z "$REPO_URL" ] || [ -z "$DATA_SCIENCE_PROJECT_NAMESPACE" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi
if [ -z "$MINIO_ACCESS_KEY" ] || [ -z "$MINIO_SECRET_KEY" ] || [ -z "$MINIO_ENDPOINT" ]; then
  echo "Error: MinIO credentials are not set."
  exit 1
fi
if [ -z "$GPU_NAME" ]; then
  echo "Error: GPU name is not set."
  exit 1
fi

# # Check if hf-creds.sh exists
# if [ ! -f "./hf-creds.sh" ]; then
#   echo "Error: hf-creds.sh not found."
#   exit 1
# fi

echo "DATA_SCIENCE_PROJECT_NAMESPACE: ${DATA_SCIENCE_PROJECT_NAMESPACE}"

# Create an ArgoCD application to deploy the application
cat <<EOF | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${DATA_SCIENCE_PROJECT_NAMESPACE:-rag-base}
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: ${DATA_SCIENCE_PROJECT_NAMESPACE:-rag-base}
  source:
    path: gitops/rag-base
    repoURL: ${REPO_URL}
    targetRevision: ${GIT_REVISION:-main}
    helm:
      values: |
        app: ${APP_NAME:-rag-base}
        argocdNamespace: ${ARGOCD_NAMESPACE:-openshift-gitops}
        
        dataScienceProjectDisplayName: ${APP_NAME:-rag-base}
        dataScienceProjectNamespace: ${APP_NAME:-rag-base}

        instanceName: ${APP_NAME:-rag-base}

        embeddings:
          - name: multilingual-e5-large-gpu
            displayName: multilingual-e5-large GPU
            model: intfloat/multilingual-e5-large
            image: quay.io/atarazana/modelcar-catalog:multilingual-e5-large
            maxModelLen: '512'
            runtime:
              templateName: vllm-serving-template
              templateDisplayName: vLLM Serving Template
              image: quay.io/modh/vllm:rhoai-2.20-cuda
              resources:
                limits:
                  cpu: '2'
                  memory: 8Gi
                requests:
                  cpu: '1'
                  memory: 4Gi
            accelerator:
              max: '1'
              min: '1'
              productName: ${GPU_NAME}

        models:
          - name: granite-3-3-8b
            displayName: Granite 3.3 8B
            model: ibm-granite/granite-3.3-8b-instruct
            image: quay.io/redhat-ai-services/modelcar-catalog:granite-3.3-8b-instruct
            maxModelLen: '23000'
            runtime:
              templateName: vllm-serving-template
              templateDisplayName: vLLM Serving Template
              image: quay.io/modh/vllm:rhoai-2.20-cuda
              resources:
                limits:
                  cpu: '8'
                  memory: 24Gi
                requests:
                  cpu: '6'
                  memory: 24Gi
            accelerator:
              max: '1'
              min: '1'
              productName: ${GPU_NAME}
          - name: llama-3-1-8b-w4a16
            displayName: Llama 3.1 8B
            model: RedHatAI/Meta-Llama-3.1-8B-Instruct-quantized.w4a16"
            image: quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-8b-instruct-quantized.w4a16
            maxModelLen: '23000'
            runtime:
              templateName: vllm-serving-template
              templateDisplayName: vLLM Serving Template
              image: quay.io/modh/vllm:rhoai-2.20-cuda
              resources:
                limits:
                  cpu: '8'
                  memory: 24Gi
                requests:
                  cpu: '6'
                  memory: 24Gi
            accelerator:
              max: '1'
              min: '1'
              productName: ${GPU_NAME}
            args:
              - '--enable-auto-tool-choice'
              - '--tool-call-parser'
              - 'llama3_json'
              - '--chat-template'
              - '/app/data/template/tool_chat_template_llama3.1_json.jinja'

        milvusApplication:
          name: milvus
          path: gitops/milvus
          targetRevision: main

        pipelinesApplication:
          name: pipelines
          path: gitops/pipelines
          targetRevision: main

        webuiApplication:
          name: webui
          openaiApiKey: "1234"
          secretKey: "1234"

        lsdApplication:
          name: lsd
          path: gitops/rag-lsd
          targetRevision: agentic
          resources:
            limits:
              cpu: '2'
              memory: 12Gi
            requests:
              cpu: 250m
              memory: 500Mi

        mcpServersApplication:
          name: mcp-servers
          path: gitops/mcp-servers
          targetRevision: agentic

        mcpServers:
          - id: mcp::bon-calculadora
            provider_id: model-context-protocol
            vcs:
              uri: https://github.com/alpha-hack-program/bon-calculadora-mcp-js.git
              ref: main
              path: .
            image: quay.io/atarazana/bon-calculadora-mcp-js:1.0.2
            mcp_transport: "sse"
            protocol: "http"
            host: bon-calculadora
            port: 8000
            uri: "/sse"
            resources:
              limits:
                cpu: '2'
                memory: 4Gi
              requests:
                cpu: 250m
                memory: 500Mi

        routerApplication:
          name: router
          path: gitops/rag-router
          targetRevision: main

        documentsConnection:
          awsAccessKeyId: ${MINIO_ACCESS_KEY}
          awsSecretAccessKey: ${MINIO_SECRET_KEY}
          awsS3Endpoint: ${MINIO_ENDPOINT}

        pipelinesConnection:
          awsAccessKeyId: ${MINIO_ACCESS_KEY}
          awsSecretAccessKey: ${MINIO_SECRET_KEY}
          awsS3Endpoint: ${MINIO_ENDPOINT}

        minio:
          name: minio
          namespace: ic-shared-minio

        documentsMilvusConnection:
          name: documents
          collectionName: documents_chunks

        milvus:
          name: milvus
          namespace: milvus
          username: root
          password: Milvus
          port: '19530'
          host: vectordb-milvus
          database: default

        mountCaCerts: "false"
        
  syncPolicy:
    automated:
      selfHeal: true
  ignoreDifferences:
    - group: apps
      kind: Deployment
      name: doc-bot
      jqPathExpressions:
        - '.spec.template.spec.containers[].image'
EOF

# # Check if the namespace exists
# if oc get namespace ${DATA_SCIENCE_PROJECT_NAMESPACE} >/dev/null 2>&1; then
#   echo "Namespace ${DATA_SCIENCE_PROJECT_NAMESPACE} already exists."
# else
#   # Create the namespace
#   oc create namespace ${DATA_SCIENCE_PROJECT_NAMESPACE}
# fi

