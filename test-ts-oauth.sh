#!/bin/bash

# Tailscale OAuth Debug Script
# Tests the exact flow that GitHub Actions uses

TS_OAUTH_CLIENT_ID="${1:-}"
TS_OAUTH_SECRET="${2:-}"
TAG="tag:github-actions"

if [ -z "$TS_OAUTH_CLIENT_ID" ] || [ -z "$TS_OAUTH_SECRET" ]; then
  echo "Usage: ./test-ts-oauth.sh <client-id> <client-secret>"
  exit 1
fi

echo "=== Step 1: Exchange OAuth credentials for access token ==="
TOKEN_RESPONSE=$(curl -s -X POST "https://api.tailscale.com/api/v2/oauth/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${TS_OAUTH_CLIENT_ID}&client_secret=${TS_OAUTH_SECRET}")

echo "$TOKEN_RESPONSE" | python3 -m json.tool

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

if [ -z "$ACCESS_TOKEN" ]; then
  echo ""
  echo "❌ Failed to get access token — check your client ID and secret"
  exit 1
fi
echo "✅ Got access token"

echo ""
echo "=== Step 2: Create ephemeral auth key with ${TAG} ==="
KEY_RESPONSE=$(curl -s -X POST "https://api.tailscale.com/api/v2/tailnet/-/keys" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"capabilities\": {
      \"devices\": {
        \"create\": {
          \"reusable\": false,
          \"ephemeral\": true,
          \"preauthorized\": true,
          \"tags\": [\"${TAG}\"]
        }
      }
    }
  }")

echo "$KEY_RESPONSE" | python3 -m json.tool

AUTH_KEY=$(echo "$KEY_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('key',''))" 2>/dev/null)

if [ -z "$AUTH_KEY" ]; then
  echo ""
  echo "❌ Failed to create auth key — this is likely the source of the GitHub Actions 403"
  exit 1
fi

echo ""
echo "✅ Auth key created successfully: ${AUTH_KEY:0:20}..."
echo ""
echo "=== OAuth flow works correctly ==="
echo "The GitHub Actions 403 may be a secret mismatch — verify your GitHub secrets match these credentials."
