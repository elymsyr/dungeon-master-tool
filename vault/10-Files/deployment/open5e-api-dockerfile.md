---
type: file-note
domain: deployment
path: open5e-api-staging/Dockerfile
layer: backend
language: yaml
status: stable
updated: 2026-06-09
tags: [file]
---

# `open5e-api-staging/Dockerfile`

> [!abstract] Primary Purpose
> Two-stage Docker build for a self-hosted/staging instance of the Open5e API (the upstream Django REST source the import tooling pulls from). Builder stage installs deps with `uv` and runs Open5e's `quicksetup`; runtime stage copies the prebuilt venv + code and serves via gunicorn on port 8888. This is the data source feeding the Open5e import pipeline, not part of the Flutter app's deploy.

## Inputs / Outputs
**Inputs**
- Build context: the Open5e API repo checkout (`pyproject.toml`, `uv.lock`, `manage.py`, Django `server/` package).
- Base images: `python:3.11-slim` (both stages); `uv` binary copied from `ghcr.io/astral-sh/uv:0.10`.

**Outputs**
- A container exposing the Open5e REST API on `:8888` (gunicorn `server.wsgi:application`).

## Dependencies & Links
- Depends on:
- Used by:
- Domain map: [[Deployment-and-Ops]]
- System flow: [[Content-Pipeline]]
- Spec / reference: [[Open5e-API]], [[build_packs]], [[sources]]

## Key Logic / Variables
- **Stage 1 `builder`** (`WORKDIR /build`): copies `uv` from the astral-sh image into `/usr/local/bin/uv`; copies only `pyproject.toml` + `uv.lock` first, then `uv sync --frozen --no-dev --no-install-project` (locked, no dev deps, deps-only for layer caching); then `COPY . .` and `uv run python manage.py quicksetup` (Open5e's DB bootstrap/seed command).
- **Stage 2 runtime** (`WORKDIR /opt/services/open5e-api`): copies the built `.venv` and the full `/build` tree from the builder; `ENV PATH="/opt/services/open5e-api/.venv/bin:$PATH"` so the venv binaries are on PATH; `CMD ["gunicorn", "-b", ":8888", "server.wsgi:application"]`.
- Pinned versions: Python `3.11-slim`, `uv` `0.10`.

## Notes
- "staging" instance — feeds the offline Dart import tool under `tool/open5e_import/` / [[sources]]. Not referenced by the Flutter [[ci-build]] release flow.
