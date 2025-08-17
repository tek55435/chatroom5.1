# Security Policy

## Supported versions
- Active branch: `master` (HEAD). Security fixes are delivered to this branch.
- Production deployments should pin container/image versions and rebuild regularly.

## Reporting a vulnerability
- Prefer a private report via GitHub Security Advisories: Repository → Security → Report a vulnerability.
- For non-sensitive issues, you may open a standard GitHub Issue.
- Please include clear reproduction steps, affected components (client/server), and any logs with secrets redacted.

## Secrets and key management
- Never commit secrets (API keys, tokens, service account JSON). The repository ignores:
  - `server/.env` (local only)
  - `openai_key.txt` (do not use; avoid storing plaintext keys in the repo)
- Use `server/.env.example` as the template for local development. Create your own `server/.env` and keep it private.
- Cloud Run (production): use Google Secret Manager for all secrets (e.g., `OPENAI_API_KEY`).
  - Store the key as a secret.
  - Grant the Cloud Run service account “Secret Manager Secret Accessor”.
  - Expose the secret to the service via environment variables.
  - Redeploy the service.

## If a secret leaks
1. Immediately rotate/revoke the key at the provider (e.g., generate a new OpenAI API key).
2. Update Secret Manager with the new value; deploy a new service revision.
3. In this repo, purge the secret from git history (filter-repo/filter-branch) and force-push.
4. Ask collaborators to re-clone (to avoid reintroducing purged objects).

## Hardening checklist (recommended)
- GitHub repository settings
  - Enable Secret scanning and Push protection (Settings → Code security and analysis).
  - Enable Dependabot alerts/updates and (optionally) CodeQL code scanning.
- Dependencies
  - Keep Node and Flutter dependencies current.
  - Avoid committing `node_modules` or build artifacts; builds are reproducible.
- Logging and data handling
  - Do not log secrets or PII. Scrub tokens/keys from server logs.
  - Set minimal required CORS/allowed origins for production.
- Cloud (GCP) access control
  - Use least-privilege service accounts.
  - Prefer private services or authenticated invokers where feasible.

## Contact
- Use GitHub Security Advisories for sensitive disclosures; GitHub Issues for non-sensitive matters.
- Include environment (local/Cloud Run), browser/device, and versions when reporting.
