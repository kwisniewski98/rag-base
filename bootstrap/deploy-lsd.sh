#!/bin/bash

# Load environment variables
. .env

# Check if the required environment variables are set
if [ -z "$ARGOCD_NAMESPACE" ] || [ -z "$REPO_URL" ] || [ -z "$DATA_SCIENCE_PROJECT_NAMESPACE" ]; then
  echo "Error: Required environment variables are not set."
  exit 1
fi

echo "DATA_SCIENCE_PROJECT_NAMESPACE: ${DATA_SCIENCE_PROJECT_NAMESPACE}"

# Create an ArgoCD application to deploy the application
cat <<EOF | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rag-lsd
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: ${DATA_SCIENCE_PROJECT_NAMESPACE:-rag-base}
  source:
    path: gitops/rag-lsd
    repoURL: ${REPO_URL}
    targetRevision: agentic
    helm:
      values: |
        app: rag-lsd
        partOf: rag-base

        namespace: rag-base
        # createNamespace: true

        argocdNamespace: openshift-gitops

        vcs:
          uri: https://github.com/alpha-hack-program/rag-lsd.git
          ref: main
          name: alpha-hack-program/rag-lsd
          path: .
          # sourceSecret: git-pat-bc-secret

        milvusDbPath: ~/.llama/milvus.db

        fmsOchestratorUrl: http://localhost

        lsdImage: quay.io/opendatahub/llama-stack:odh
        lsdPort: 8321

        lsdResources:
          limits:
            cpu: '2'
            memory: 12Gi
          requests:
            cpu: 250m
            memory: 500Mi

        mcpServers:
          - id: mcp::bon-calculadora
            provider_id: model-context-protocol
            endpoint:
              uri: "http://bon-calculadora:8000/sse"

        models:
          - name: granite-3-3-8b
            url: http://granite-3-3-8b-predictor:8080/v1
            model: granite-3-3-8b
            api_key: ""
            tls_verify: false
            max_tokens: 4096
          - name: llama-3-1-8b-w4a16
            url: http://llama-3-1-8b-w4a16-predictor:8080/v1
            model: llama-3-1-8b-w4a16
            api_key: ""
            tls_verify: false
            max_tokens: 4096

        prompts:
          - name: context
            description: "Prompt for answering general questions with context"
            template: |
              Given the following context:
              <context>
              {context}
              </context>

              Answer the question: {query}
              Don't use any information outside the context provided. Don't make up any information. If you don't know the answer, just say 'I don't know'.

          - name: default
            description: "Prompt for answering questions without context"
            template: |
              Answer the question: {query}
              Don't use any context. Don't make up any information. If you don't know the answer, just say 'I don't know'.
          

        
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


