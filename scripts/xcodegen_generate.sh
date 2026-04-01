#!/usr/bin/env bash
set -euo pipefail

if [[ -f "project.local.yml" ]]; then
  INCLUDE_LOCAL_PROJECT_YML=YES xcodegen generate -s project.yml
else
  INCLUDE_LOCAL_PROJECT_YML=NO xcodegen generate -s project.yml
fi
