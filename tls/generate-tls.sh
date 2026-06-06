#!/usr/bin/env bash

echo "Generating self-signed TLS certificate..."

mkdir -p tls

openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout tls/tls.key \
  -out tls/tls.crt \
  -subj "/CN=wisecow.local/O=wisecow"

echo ""
echo "Certificate generated:"
echo "  tls/tls.crt  --> the certificate"
echo "  tls/tls.key  --> the private key"
echo ""
echo "Now run this to create the Kubernetes secret:"
echo "  kubectl create secret tls wisecow-tls-secret --cert=tls/tls.crt --key=tls/tls.key"
