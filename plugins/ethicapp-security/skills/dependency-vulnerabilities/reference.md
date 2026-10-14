# Reference: worked example, patterns and pitfalls

Companion to [SKILL.md](SKILL.md). Facts here come from real remediation
work on the EthicApp repositories; they illustrate the procedure and are not
a substitute for each repository's `AGENTS.md`.

## Worked example: ethicapp-ai-additions, 2026-10-14

Issues #160 (Argumentation Tutor) and #161 (Polyadic Agents), PRs #162 and
#163.

**Audit.** `pip-audit` inside the tutor image (Flask API and Celery worker
share one `requirements.txt`): 16 advisories in two direct pins, `PyJWT`
2.13.0 and `cryptography` 49.0.0. `npm audit` on the tutor frontend
lockfile: 37 advisories (2 critical, 27 high), direct ones in `axios`,
`react-router-dom`, `vite`, `typescript-eslint`, `eslint`; all fixable
without a major upgrade. Dependabot alerts were disabled, so nothing had
surfaced them.

**Relevance check.** The shared `ethicapp_ai_auth` SDK loads JWKS keys with
`jwt.PyJWK` and verifies with `jwt.decode`; it does not use `PyJWKClient`,
so the JWKS-client advisories did not apply while the JWK-parsing and
algorithm-confusion ones did. The issue text was corrected to say exactly
that. `cryptography`'s advisory (PKCS7 decryption) was not used at all; it
was bumped anyway.

**Fix.** `PyJWT[crypto]` to 2.15.1 and `cryptography` to 50.0.2 in the
tutor; the same `PyJWT` bump in Polyadic (same SDK, older pin) and a
`>=2.15.1` floor in the SDK's `pyproject.toml`. `npm audit fix` without
`--force`; `package.json` unchanged because its ranges already admitted the
fixed versions.

**Verification.** Tutor image rebuilt: `pip check` clean, `pip-audit` clean,
233 tutor tests and 95 shared-SDK tests inside the image. Frontend on
`node:24-alpine`: `npm ci && npm run build` green, `npm audit` 0. Lint
showed 11 problems both before and after (checked by running it with the
old lockfile too), so they were reported as pre-existing and left alone.

**Scope discipline.** The Polyadic image still had 30 advisories in 6
packages, including `agentscope` with no fix below 1.0.19 and `starlette`
reachable only through a `fastapi` bump. That became its own issue (#161)
and PR, stacked on the first one because it depended on the `PyJWT` bump.

## Pattern: compatibility pins under a pinned framework

Polyadic pins `agentscope` 1.0.x, which declares its own dependencies
loosely. Three transitive pins exist, each with an inline comment:

- `openai` 2.x: the framework's streaming parser evaluates
  `"data" in choice.delta.audio`; openai 3.x sets `audio=None`, so ordinary
  text chunks raise `TypeError`. The factory runs non-streaming, so the
  fault was latent, but the pin keeps the SDK on the verified line.
- `mcp` 1.x: the framework imports `streamablehttp_client`, which mcp 2.0
  renamed.
- `tqdm`: the framework imports it without declaring it; it arrived
  transitively through openai 2.x and would vanish with openai 3.x.

Each of these was found by importing the real framework in the rebuilt
image, not by reading metadata. A regression test
(`tests/test_openai_adapter_compat.py`) drives the real adapter through an
`httpx.MockTransport` in both streaming modes; when the openai pin was
dropped experimentally, it failed with exactly the production error. The
same test passed with the framework upgraded to 1.0.21, which proved the
pins were still needed after the upgrade.

## Pattern: stubbed suites and real-package checks

Suites that stub an SDK into `sys.modules` at import time (with
`setdefault`) will hand the stub to any later test module in the same run.
A real-package check must therefore import lazily, detect the stub
(`getattr(sys.modules["agentscope"], "__file__", None) is None`), and
re-run itself in a child interpreter when stubbed, skipping cleanly where
the real package is not installed. Run it inside the image to see it pass.

## Pitfalls seen

- A `requirements.txt` stored as UTF-16 with null bytes: most tools cannot
  read it. Rewrite as ASCII; `git show HEAD:path | tr -d '\0'` recovers the
  old pins for comparison.
- `pip-audit` prints a "Skip Reason" table for packages not on PyPI (local
  SDKs on `PYTHONPATH`); that is not a finding. Check the exit code and the
  "No known vulnerabilities found" line, not only the tail of the output.
- An image that has test tools installed at runtime (`pytest`, fake
  backends) widens the audit surface; note it as a follow-up, do not strip it
  in the same PR.
- `npm audit fix` can print `allowScripts` warnings on a local npm version
  different from the image's; confirm `npm ci` on the production Node image
  before treating them as a problem.
- Lint results can change with a `typescript-eslint` / `eslint` bump. Run
  the lint with the previous lockfile on the same Node image to separate
  pre-existing problems from new ones.
- A build whose dependency set resolves fine can still break at runtime on
  an API argument the configured model rejects (the tutor's
  `reasoning_effort` incident, #164). That is not a dependency problem;
  diagnose from the service logs, and do not pin anything to "fix" it.
- When Docker's engine is down or its disk is full, builds fail in ways
  that look like dependency errors. Check `docker info` before concluding.
