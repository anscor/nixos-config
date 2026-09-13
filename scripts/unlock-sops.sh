#!/usr/bin/env bash
set -euo pipefail

host="${1:?用法: unlock-sops.sh <tencent|ai>}"
mkdir -p /etc/sops
age -d -o /etc/sops/age.key "secrets/age-keys/${host}.key.age"
chmod 600 /etc/sops/age.key
echo "已写入 /etc/sops/age.key"
