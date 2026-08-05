# AGENTS.md

# Enterprise Official Documentation First Engineering Policy

**Version:** 3.0
**Enforcement Level:** Mandatory
**Priority:** Highest
**Applies To:** All software engineering activities

---

# 1. Absolute Engineering Rule

## NEVER IMPLEMENT FROM MEMORY OR ASSUMPTION.

Before performing any development activity, the agent MUST:

1. Understand the task.
2. Inspect the existing system.
3. Identify all technologies involved.
4. Detect exact versions.
5. Consult official documentation.
6. Verify supported approaches.
7. Analyze risks and side effects.
8. Implement only after verification.

No exceptions.

Speed must never override correctness.

---

# 2. Official Documentation First Principle

Official documentation is the single source of truth.

The agent MUST consult official sources before:

* Writing code.
* Editing code.
* Adding dependencies.
* Removing dependencies.
* Changing architecture.
* Using APIs.
* Using SDKs.
* Changing configuration.
* Migrating versions.
* Debugging unknown behavior.
* Optimizing performance.
* Applying security changes.

If official documentation is not available:

STOP.

Do not guess.

Ask the user for clarification or additional information.

---

# 3. Mandatory Engineering Workflow

Every task MUST follow this order.

---

# Phase 1 — Understand

Before any action:

Determine:

* User objective.
* Existing behavior.
* Expected behavior.
* Constraints.
* Acceptance criteria.
* Potential risks.

---

# Phase 2 — Inspect

Inspect the repository.

Required checks:

* Project structure.
* Source code.
* Configuration.
* Dependencies.
* Build system.
* Runtime environment.
* CI/CD configuration.
* Tests.
* Existing documentation.

Never modify unfamiliar code.

---

# Phase 3 — Identify Technology Versions

Exact versions MUST be discovered.

Verify:

* Language version.
* Framework version.
* SDK version.
* Library versions.
* Compiler versions.
* Platform versions.
* Database versions.
* Toolchain versions.

Never assume:

* Latest version.
* Compatible version.
* Available API.

---

# Phase 4 — Official Documentation Verification

Before implementation, consult:

## Priority Order

1. Official documentation
2. Official specifications
3. Official API references
4. Official SDK documentation
5. Official GitHub repository
6. Official release notes
7. Official migration guides
8. Official examples
9. Official source code

---

Never use as authoritative references:

* Stack Overflow
* Reddit
* Medium
* Personal blogs
* Random tutorials
* Unofficial videos
* AI-generated solutions
* Unknown GitHub repositories

These may only provide hints, never decisions.

---

# Phase 5 — Technical Verification

Confirm:

* API exists.
* API is supported.
* API matches current version.
* Recommended usage pattern.
* Security requirements.
* Performance considerations.
* Known limitations.
* Deprecations.
* Breaking changes.
* Migration requirements.

---

# 4. Mandatory Verification Gate Before Changes

Before ANY modification operation:

The agent MUST produce a Verification Report.

Modification operations include:

* Editing files.
* Creating files.
* Deleting files.
* Moving files.
* Copying files.
* Changing permissions.
* Installing packages.
* Updating dependencies.
* Running destructive commands.
* Changing configuration.

---

# Verification Report

## 1. Technology Inventory

Include:

* Technology name.
* Exact version.
* Location where version was discovered.

Example:

```
Flutter:
Version: X.Y.Z
Source: pubspec.yaml
```

---

## 2. Official Documentation Evidence

Include:

* Official documentation source.
* Documentation tool used.
* Exact page/reference.
* Relevant section.

Example:

```
Source:
Official Flutter Documentation

Reference:
State Management Guide

Finding:
Recommended architecture pattern confirmed.
```

---

## 3. Implementation Justification

Explain:

* Why this solution is correct.
* Why it matches official guidance.
* Why alternatives were rejected.
* Compatibility confirmation.

---

## 4. Impact Analysis

Analyze:

### Existing Behavior

What remains unchanged.

### New Behavior

What changes.

### Risks

Possible failures.

### Security

Potential security impact.

### Performance

Potential performance impact.

### Compatibility

Affected platforms and versions.

### Testing

Required validation.

---

Only after completing this report may changes begin.

---

# 5. Change Management Rules

Every change must be:

* Minimal.
* Necessary.
* Reviewable.
* Reversible.
* Tested.
* Documented.

Avoid:

* Unnecessary refactoring.
* Large unrelated changes.
* Dependency changes without approval.
* Architecture changes without justification.

---

# 6. Dependency Management Policy

Before adding, removing, or updating dependencies:

Verify:

* Official package documentation.
* Version compatibility.
* Security advisories.
* Breaking changes.
* Migration instructions.
* Maintenance status.

Never:

* Add packages without justification.
* Upgrade blindly.
* Replace dependencies casually.

---

# 7. API and SDK Rules

Before using any API:

Verify:

* Official API reference.
* Correct version.
* Required permissions.
* Authentication requirements.
* Error handling.
* Rate limits.
* Security requirements.
* Lifecycle behavior.

Never invent:

* Methods.
* Classes.
* Endpoints.
* Parameters.
* Configuration keys.

---

# 8. Security Engineering Requirements

Security is mandatory.

Always:

* Protect credentials.
* Validate inputs.
* Sanitize outputs.
* Follow secure defaults.
* Apply least privilege.
* Protect user data.
* Handle failures safely.
* Use official security recommendations.

Never:

* Hardcode secrets.
* Disable security protections.
* Skip validation.
* Ignore warnings.
* Expose private information.
* Reduce security for convenience.

---

# 9. Debugging Rules

For bugs:

Mandatory process:

1. Reproduce.
2. Collect evidence.
3. Identify root cause.
4. Consult official documentation.
5. Confirm expected behavior.
6. Apply minimal fix.
7. Add regression protection.
8. Validate.

Do not patch symptoms without understanding causes.

---

# 10. Testing and Validation Gate

Before completion:

Verify:

## Build

* Project builds successfully.

## Tests

Run available:

* Unit tests.
* Integration tests.
* UI tests.
* Static analysis.
* Lint checks.

## Regression

Confirm:

* Existing features still work.
* No unexpected behavior introduced.

---

# 11. Production Readiness Checklist

Before declaring completion:

Required:

* Correct implementation.
* Official documentation verified.
* Versions confirmed.
* Security reviewed.
* Performance considered.
* Tests completed.
* Documentation updated.
* No known regressions.

---

# 12. Anti-Hallucination Enforcement

The agent MUST NOT fabricate:

* Documentation.
* APIs.
* Commands.
* Libraries.
* Features.
* Versions.
* Configuration.
* Compatibility claims.

When uncertain:

STOP.

Say:

"I need official documentation verification before proceeding."

Then verify.

---

# 13. Agent Behavior Rules

The agent must:

* Think before acting.
* Verify before coding.
* Prefer official sources.
* Explain decisions.
* Minimize risk.
* Preserve existing behavior.
* Ask when uncertain.

The agent must not:

* Guess.
* Assume.
* Skip verification.
* Use outdated knowledge.
* Apply undocumented solutions.

---

# 14. Final Engineering Standard

Every delivered change must meet this standard:

## Correct

Works according to specification.

## Secure

Protects users and systems.

## Maintainable

Readable and understandable.

## Compatible

Works with supported versions.

## Tested

Validated against regressions.

## Documented

Future developers can understand it.

## Production Ready

Safe for real-world usage.

---

# FINAL COMMANDMENT

**No implementation without official documentation verification.**

**No assumption without evidence.**

**No modification without understanding.**

**No completion without validation.**

The highest priority is:

Correctness → Security → Maintainability → Reliability → Performance → Speed.

---

**END OF AGENTS.md**
