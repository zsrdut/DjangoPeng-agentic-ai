#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/DjangoPeng/agentic-ai"
REPO_DIR="${HOME}/projects/agentic-ai"
PROJECT_ROOT="${PROJECT_ROOT:-${HOME}/projects/xhs-auto-publisher}"

echo "[setup] step 1/4 - clone or update repo"
if [ -d "${REPO_DIR}/.git" ]; then
  git -C "${REPO_DIR}" pull
else
  git clone "${REPO_URL}" "${REPO_DIR}"
fi

echo "[setup] step 2/4 - copy xhs-auto-publisher to deploy dir"
rm -rf "${PROJECT_ROOT}"
cp -r "${REPO_DIR}/xhs-auto-publisher" "${PROJECT_ROOT}"

echo "[setup] step 3/4 - install system dependencies"
bash "${PROJECT_ROOT}/deploy/install_system_ubuntu.sh"

echo "[setup] step 4/4 - init project environment"
bash "${PROJECT_ROOT}/deploy/bootstrap_project.sh"

echo "[setup] writing .env (MODE=draft)"
cp "${PROJECT_ROOT}/deploy/env.example" "${PROJECT_ROOT}/.env"
sed -i 's/^MODE=.*/MODE=draft/' "${PROJECT_ROOT}/.env"

echo "[setup] done - project ready at ${PROJECT_ROOT}"
echo "[setup] run with: bash ${PROJECT_ROOT}/deploy/run_with_xvfb.sh"
