#!/bin/sh
ARGOCD_APP_NAME=pipelines

# Load environment variables
DATA_SCIENCE_PROJECT_NAMESPACE="pipelines"

helm template . --name-template ${ARGOCD_APP_NAME} \
  --set dataScienceProjectNamespace=${DATA_SCIENCE_PROJECT_NAMESPACE} \
  --set dataScienceProjectDisplayName=${DATA_SCIENCE_PROJECT_NAMESPACE} \
  --include-crds