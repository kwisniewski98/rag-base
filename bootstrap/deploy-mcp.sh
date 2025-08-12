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
  name: rag-mcp
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: ${DATA_SCIENCE_PROJECT_NAMESPACE:-rag-base}
  source:
    path: gitops/mcp-servers
    repoURL: ${REPO_URL}
    targetRevision: agentic
    helm:
      values: |
        app: rag-mcp-servers
        partOf: rag-base

        namespace: rag-base
        # createNamespace: true

        argocdNamespace: openshift-gitops

        servers:
          - id: mcp::bon-calculadora
            provider_id: model-context-protocol
            vcs:
              uri: https://github.com/alpha-hack-program/bon-calculadora-mcp-js.git
              ref: main
              path: .
            image: quay.io/atarazana/bon-calculadora-mcp-js:1.0.1
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


