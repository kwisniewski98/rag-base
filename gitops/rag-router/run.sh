#!/bin/sh
ARGOCD_APP_NAME=rag-router

# Load environment variables
DATA_SCIENCE_PROJECT_NAMESPACE="rag-base"

helm template . --name-template ${ARGOCD_APP_NAME} \
  --set namespace=${DATA_SCIENCE_PROJECT_NAMESPACE} \
  --set mountCaCerts="true" \
  --include-crds