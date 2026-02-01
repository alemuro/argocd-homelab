#!/bin/bash

# A script to create a sealed secret for a Cloudflare tunnel.

# Namespace for the tunnel secrets. Change if needed.
NAMESPACE="ingress"

read -p "Enter the public domain: " public_domain
read -p "Enter the tunnel CNAME: " tunnel_cname
read -sp "Enter the token: " token
echo

# Check if the public_domain is set
if [ -z "$public_domain" ]; then
  echo "Public domain cannot be empty."
  exit 1
fi

# Create applications/ingress/tunnels directory if it does not exist
mkdir -p applications/ingress/tunnels

# Create a Kubernetes secret and pipe it to kubeseal
kubectl create secret generic "${public_domain}-tunnel" \
  --namespace "${NAMESPACE}" \
  --from-literal=PUBLIC_DOMAIN="${public_domain}" \
  --from-literal=TUNNEL_CNAME="${tunnel_cname}" \
  --from-literal=TOKEN="${token}" \
  --dry-run=client -o yaml | \
  kubeseal --controller-name sealed-secrets --controller-namespace sealed-secrets --format yaml > "applications/ingress/tunnels/${public_domain}.yaml"

echo "Sealed secret created at applications/ingress/tunnels/${public_domain}.yaml"
