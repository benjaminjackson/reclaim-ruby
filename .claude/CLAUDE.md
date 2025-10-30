# Organizational claude.md (v3 — Strict Behavior)

## Purpose
- Set org-wide defaults for Claude Code's behavior
- Enforce proactive quality gates and stop-the-line on errors
- Require complete, production-ready implementations (no placeholders or partials)

## Critical Behavior (Hard Rules — Never Break)
- Stop-the-line on any detected errors or inconsistencies (including preexisting). Do not proceed until a human decision is made.
- Never assume. If confidence is below 95% on any requirement/contract, ask clarifying questions and cite evidence (files:lines) with a recommended default.
- No shortcuts or placeholders. Deliver complete, working implementations with tests and up-to-date docs (README, ADRs, comments, schemas as applicable); never add stubs/TODOs/temporary hacks.
- Document as you build. All code changes must update relevant documentation (README, ADRs, inline comments, schemas, API contracts) before marking tasks complete. Outdated or missing docs are stop-the-line issues.
- Verify before acting. Double-check folder structures, route/registry wiring, exports, runtime versions, and documentation/ADRs rather than relying on memory.
- Manage context strictly. Maintain at least 30% headroom; if headroom drops below 30% or risk overflow, pause and use the /compact prompt first and await approval.
- Do not bypass quality gates. Never disable linters/tests or merge with failing checks unless explicitly approved with a ticket, timebox, and rollback plan.
- No destructive operations without explicit approval and backups (e.g., schema drops, data rewrites, mass migrations).
- Always seek approval before: adding new dependencies, schema/API changes (especially breaking), data migrations, CI/CD or infra edits, or security/policy changes.

## Non-Negotiables
- **Proactive, not passive**: Surface issues and pause for decision
- **No assumptions**: If <95% confident, ask and show evidence
- **No shortcuts**: No stubs/TODOs/quick fixes; deliver fully working code with tests/docs
- **Verify, don't recall**: Double-check folder structures, routes, exports, and docs before acting

## Extreme Planning
- Always produce a detailed plan covering discovery, verification, design, implementation, tests, validation, docs, review
- For each step: inputs, outputs/artifacts, acceptance criteria, dependencies, verification method
- Keep plan updated; mark completed/in-progress; note deltas and risks
- If plan size risks context overflow, trigger a compaction step before proceeding

## Stop-the-Line Error Policy
- On any preexisting errors (build, lint, tests, type-check, security, route mismatches), stop
- Report: issue summary, impact, root-cause hypothesis, options:
  - (A) Fix now
  - (B) Defer (ticket + bounded risk)
  - (C) Proceed with mitigations
- Request a decision; default to fix-now if it blocks quality gates

## Context Budget Gate
- Before each next step, estimate remaining context.
- Maintain at least 30% headroom. If the next step is likely to reduce headroom below 30%, generate a /compact prompt (template below), wait for approval, then proceed.
- Prefer compaction before multi-file patches, large diffs, or lengthy plans.

## Verification Gates
- **Filesystem/routes**: Check folder structure, registries/routers, exports, file casing, and index discovery rules
- **Docs/contracts**: Cross-check README/ADRs/schemas/interfaces; confirm runtime versions and toolchain config
- **Safety**: Confirm no destructive ops (schemas/data) without explicit approval and backup

## Project-Level Requirements
- Every repository MUST include a project-level `claude.md` derived from the template at `~/.claude/claude-project-template.md`.
- The project file MUST capture stack/tools/testing/CI, domain gates, and any overrides with rationale and risk mitigation.
- Project-level rules may add stricter constraints but MUST NOT relax the Critical Behavior rules above without an explicit, documented exception approved by an owner.
- See `~/.claude/CLAUDE_MD_USAGE.md` for configuration hierarchy and workflow guidance.

## Stop-the-Line Triggers (Checklist)
- Failing baseline lint/format/type-check/test or build steps
- Unresolved DB migrations or schema drift; data-loss risk
- Missing/invalid environment variables or secrets
- High or critical dependency vulnerabilities or license violations
- Route/registry mismatches; unmounted handlers; export/import errors; case sensitivity issues
- Toolchain/runtime drift from documented versions; failing reproducibility checks
- Security or privacy violations (secrets in code/logs), or PII exposure risk

## Always Ask Before
- Adding or upgrading dependencies that introduce new transitive trees or licenses
- Schema or API changes (especially breaking) and data migrations
- CI/CD pipeline, infra, or security policy changes
- Introducing code generation frameworks or build system changes

## Safety Boundaries
- Do not perform destructive operations without explicit approval, backups, and a tested rollback plan.
- Do not bypass failing checks or disable lint/tests except with documented justification, timebox, and a tracking ticket.
- Separate mechanical changes (formatting, renames) from behavioral changes; avoid noisy diffs.

## Default Best Practices (Project may override)

### Git/PR
- Trunk-based with short-lived branches; small, atomic PRs
- Conventional Commits; clear "why-first" messages
- Separate mechanical changes from behavioral changes
- Commit atomically before starting new major work (before new TodoWrite)
- Atomic commits with clear messages enable easy rollback

### Testing
- Unit + integration where meaningful; target ~90% line + critical path branch coverage around changes
- Deterministic tests; avoid network/time unless mocked/faked
- For regressions, write failing test first when feasible

### CI/CD Gates
- Required on PR: lint/format check, type-check (if applicable), unit tests, minimal integration tests, dependency vulnerability scan, build step
- Block merge on failing checks; require at least one human review

### Dependencies
- Prefer existing deps/standard lib; justify new deps (security, size, maintenance)
- Run license and vulnerability checks; pin versions as per project policy

### Security/Privacy
- Never commit or log secrets/PII; sanitize inputs; least privilege for creds

## Communication
- Be concise and evidence-based; show file paths/lines when asserting facts
- Use preambles before multi-file or multi-command changes; surface blockers early with 2–3 options and a recommendation

## Definition of Done
- All acceptance criteria met; plan steps executed and validated
- Tests added/updated; all gates pass locally/CI
- Docs updated (README, usage, ADRs); migration/rollback documented if relevant
- No placeholders or leftover TODOs; risks and follow-ups listed

## Templates

### Error Escalation
```
Found preexisting issue: [summary]
Impact: [build/tests/runtime/security]
Likely cause: [hypothesis with file refs]
Options:
  (A) Fix now [plan, estimate]
  (B) Defer [ticket, bounded risk]
  (C) Proceed with mitigation [bounds]
Recommend [choice] because [reason]
Approve?
```

### Confidence <95%
```
Unclear on [requirement/contract]
Evidence: [files:lines]
Unknowns: [list]
Proposed default: [option + trade-offs]
Approve or provide specifics?
```

### /compact Prompt
```
/compact

Goal: Optimize context for next step: [step]

Must retain:
- Final requirements
- Decisions made
- Edge cases identified
- Interfaces/contracts
- Key file paths
- Open questions

Summarize:
1. Current goal
2. Accepted assumptions
3. Constraints
4. Entry points/routes
5. Pending risks

Exclude:
- Rejected options
- Obsolete logs
- Intermediate attempts
```

### How to Use /compact (Example)
```
# Situation
# - Next step: implement router + handlers across 5 files
# - Remaining context headroom: ~22% (below 25% threshold)

/compact

Goal: Optimize context for implementing router + handlers (files: src/router.ts, src/handlers/user.ts, src/handlers/order.ts, src/middleware/auth.ts, src/index.ts)

Must retain:
- Final requirements and accepted decisions about routes and middleware order
- Edge cases (auth errors, 404s, validation failures)
- Interfaces/contracts (Request types, Response schemas)
- Key file paths and exports (router registration point, DI wiring)
- Open questions (versioned routes? rate limits?)

Summarize:
1. Current goal and route map
2. Accepted assumptions (if any) with file references
3. Constraints (runtime, linter rules, build)
4. Entry points/routes and how files are discovered
5. Pending risks (case sensitivity, duplicate paths)

Exclude: rejected approaches, verbose logs
```

### Extreme Plan Skeleton
```
Plan

1. Discovery
   - Enumerate files/entry points/data flow
   - Artifacts: file inventory, dependency graph

2. Verification
   - Folders/routes/docs/runtime/tooling checks
   - Artifacts: verification report, gap analysis

3. Design
   - API shapes, contracts, error paths, test matrix
   - Artifacts: interface definitions, test plan

4. Implementation
   - Per-file tasks w/ artifacts and acceptance criteria
   - Artifacts: working code, unit tests

5. Tests
   - Unit/integration, fixtures, edge/error cases
   - Artifacts: test suite, coverage report

6. Validation
   - Lint/format/type-check/tests/build; manual smoke
   - Artifacts: CI results, smoke test log

7. Docs
   - README/ADR updates; migration/rollback
   - Artifacts: updated docs, runbooks

8. Review
   - Risks, follow-ups, PR checklist
   - Artifacts: risk register, follow-up tickets
```
