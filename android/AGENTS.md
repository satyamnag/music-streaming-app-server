# AGENTS.md

# MANDATORY FIRST ACTION — READ THIS FILE BEFORE ANYTHING

Before doing ANYTHING and EVERYTHING — before any investigation, any question,
any command, any code change, any commit, any configuration, any debugging, or
any engineering decision of any kind — the agent MUST first read this AGENTS.md
file completely and in full, and strictly follow every instruction it contains.

This obligation is ABSOLUTE / MANDATORY / NON-NEGOTIABLE / ZERO EXCEPTIONS and
applies to EVERY single action, without exception, every time.

# Enterprise Autonomous Engineering Excellence & Zero-Assumption Development Policy

## Version: 5.0

## Enforcement Level

ABSOLUTE / MANDATORY / NON-NEGOTIABLE / ZERO EXCEPTIONS

------------------------------------------------------------------------

# Supreme Engineering Commandment

## NEVER GUESS.

## NEVER ASSUME.

## NEVER IMPLEMENT FROM MEMORY.

## NEVER TRUST UNVERIFIED INFORMATION.

Every engineering action MUST follow:

Evidence → Official Documentation Verification → System Understanding →
Risk Analysis → Planning → Small Atomic Implementation → Testing →
Security Validation → Review → Documentation → Commit → Continue

No step may be skipped.

------------------------------------------------------------------------

# Engineering Priority Hierarchy

1.  Correctness
2.  Security
3.  Reliability
4.  Maintainability
5.  Compatibility
6.  Scalability
7.  Performance
8.  Developer Experience
9.  Speed

Fast but unsafe solutions are forbidden.

------------------------------------------------------------------------

# Official Documentation Is The Absolute Source Of Truth

Before ANY:

-   Code change
-   Debugging
-   Bug fix
-   Dependency change
-   Configuration change
-   API usage
-   SDK usage
-   Database change
-   Cloud change
-   Infrastructure change
-   Security change
-   Architecture change
-   Migration
-   Deployment change

The agent MUST verify official documentation first.

------------------------------------------------------------------------

# Approved Official Documentation MCP Sources

The agent MUST use appropriate official documentation MCP sources:

-   context7
-   ref
-   gitmcp
-   deepwiki
-   docker
-   freeweb
-   exa
-   terraform
-   aws-knowledge
-   markitdown
-   pdf-reader
-   pdf-mcp
-   huggingface
-   repomix
-   godot
-   clickhouse
-   excel
-   youtube-transcript
-   duckduckgo
-   everything
-   selenium
-   puppeteer
-   browserbase
-   memory
-   context-awesome
-   flux
-   sequential-thinking
-   appium-mcp
-   scrcpy-mcp
-   agent-device
-   uiautomator2-mcp

------------------------------------------------------------------------

# Android Mobile App Testing (Mandatory MCP Servers)

For ANY Android app verification, UI testing, device interaction, screenshot
capture, or end-to-end testing, the agent MUST use the dedicated Android MCP
servers below instead of ad-hoc `adb shell` / `uiautomator dump` commands,
whenever the servers are available and appropriate:

-   **appium-mcp** — official Appium-team MCP server (Android + iOS). Use for
    Appium-driven automation: sessions, element finding, gestures, screenshots,
    device control.
-   **scrcpy-mcp** — Android device control + vision via ADB and scrcpy. Use
    for screen capture, tap/swipe/type input, app launch, UI element finding,
    file transfer, and shell commands on the connected device/emulator.
-   **agent-device** — Callstack's mobile automation CLI + MCP server (iOS,
    Android, HarmonyOS). Use for app install/launch, UI interaction, snapshots,
    and verification workflows.
-   **uiautomator2-mcp** — Android automation via uiautomator2
    (tap/swipe/type/screenshot/app management). Currently DISABLED in the
    opencode config: upstream v0.1.1 crashes (mcp 2.x removed
    `mcp.server.fastmcp`; mcp 1.9.0 still fails tool registration). Do NOT
    enable until upstream is fixed; use appium-mcp / scrcpy-mcp / agent-device.

## Prerequisites (verify before use)

-   Target device/emulator visible via `adb devices` (ADB is at
    `/home/ubuntu/Android/Sdk/platform-tools`; ensure it is on PATH when
    invoking these servers).
-   Node.js 22+ is required by appium-mcp, scrcpy-mcp and agent-device — use
    `/opt/node22/bin/npx` (system node is v18 and too old).
-   scrcpy and ffmpeg are optional but recommended for scrcpy-mcp performance;
    the server falls back to ADB when they are absent.
-   uv/uvx is used for the Python-based uiautomator2-mcp (currently disabled).

## Usage Rules

-   When a task matches one of these servers, prefer the server's MCP tools
    over raw `adb shell` / `uiautomator dump` invocations.
-   Verify the server is connected (its tools are actually available) before
    relying on it; if a server fails to start, report the error and fall back
    to the next appropriate server rather than guessing.
-   Confirm the target device with the server's device-listing tool first
    (the usual target for this workspace is emulator `emulator-5554`).

------------------------------------------------------------------------

# Project-Specific Official Documentation (Mandatory Sources Of Truth)

For ANY operation involving the technologies below, the agent MUST verify
against these official sources FIRST, using the Approved Official
Documentation MCP Sources (context7, ref, gitmcp, deepwiki, exa, etc.). Direct
web/curl fetching is NOT a substitute for MCP-based documentation retrieval,
and no implementation, debugging, bug fix, configuration change, API/SDK usage,
or architecture change may begin before it is complete:

## Media Playback & Streaming

-   **media_kit (Flutter media library):** https://github.com/media-kit/media-kit
-   **media_kit official docs:** https://media-kit.dev/
-   **mpv manual (libmpv native engine):** https://mpv.io/manual/master/
-   **Opus codec (Xiph.Org):** https://opus-codec.org/
-   **Opus codec specification (IETF RFC 6716):** https://datatracker.ietf.org/doc/html/rfc6716
-   **FFmpeg (demuxer/decoder used by libmpv):** https://ffmpeg.org/

These links are the authoritative source for: supported audio formats, codecs,
containers, streaming/network options, caching/buffering behavior, and codec
efficiency claims. No media/streaming decision may be made without consulting
them.

------------------------------------------------------------------------

# MCP Verification Enforcement

Before ANY implementation, the agent MUST use the Approved Official
Documentation MCP Sources listed above (context7, ref, gitmcp, deepwiki, exa,
etc.) to fetch and verify all documentation. Direct web/curl fetching is NOT a
substitute for MCP-based documentation retrieval. The agent MUST NOT begin any
coding change until documentation verification is completed via MCP sources.

Before ANY implementation:

1.  Identify technologies involved.
2.  Locate official documentation via the approved MCP sources.
3.  Verify versions via MCP-fetched official documentation.
4.  Verify APIs via MCP-fetched official documentation.
5.  Verify security recommendations via MCP-fetched official documentation.
6.  Verify compatibility via MCP-fetched official documentation.
7.  Verify migration notes and breaking changes via MCP-fetched official
    documentation.

Only after MCP-based verification may implementation begin.

------------------------------------------------------------------------

# Anti-Hallucination Rule

The agent MUST NEVER fabricate:

-   APIs
-   Commands
-   Versions
-   Libraries
-   Configuration
-   Features
-   Compatibility claims

If uncertain:

"I need official documentation verification before proceeding."

------------------------------------------------------------------------

# Universal Problem Decomposition

Every problem MUST be divided:

Mission → Phase → Milestone → Task → Atomic Change

Every atomic change must be:

-   Small
-   Necessary
-   Testable
-   Reversible
-   Documented
-   Secure

------------------------------------------------------------------------

# Mandatory Engineering Workflow

## Phase 1: Understand

Identify:

-   Objective
-   Current behavior
-   Expected behavior
-   Constraints
-   Acceptance criteria
-   Risks

## Phase 2: Inspect

Inspect:

-   Repository structure
-   Source code
-   Configuration
-   Dependencies
-   Build system
-   Runtime environment
-   CI/CD
-   Tests
-   Documentation

Never modify unfamiliar code.

## Phase 3: Version Discovery

Verify:

-   Language versions
-   Framework versions
-   SDK versions
-   Libraries
-   Compilers
-   Platforms
-   Toolchains

## Phase 4: Documentation Verification

Verify — using ONLY the Approved Official Documentation MCP Sources (context7,
ref, gitmcp, deepwiki, exa, etc.) — the following for every technology
involved. Direct web/curl fetching is NOT a substitute for MCP-based
documentation retrieval:

1.  Official documentation
2.  Official specifications
3.  Official API references
4.  Official SDK documentation
5.  Official repositories
6.  Release notes
7.  Migration guides

------------------------------------------------------------------------

# Verification Report Before Changes

Before editing:

## Technology Inventory

Technology: Version: Official Source: Verification Result:

## Documentation Evidence

Source: Reference: Finding: Compatibility: Security Notes:

## Implementation Justification

Explain:

-   Why solution is correct
-   Why alternatives were rejected
-   Security reasoning
-   Compatibility reasoning

## Impact Analysis

Analyze:

-   Existing behavior
-   New behavior
-   Risks
-   Security
-   Performance
-   Compatibility
-   Rollback strategy
-   Testing strategy

------------------------------------------------------------------------

# Safe Implementation Rules

Every change MUST:

-   Follow existing architecture
-   Minimize changes
-   Preserve compatibility
-   Use secure defaults
-   Include validation

------------------------------------------------------------------------

# Dependency Security

Before adding dependencies verify:

-   Official package source
-   Authenticity
-   Security advisories
-   License
-   Maintenance status
-   Compatibility

Never install unknown packages.

------------------------------------------------------------------------

# Secret Protection

Always:

-   Protect credentials
-   Use secret managers
-   Apply least privilege
-   Validate permissions

Never:

-   Hardcode secrets
-   Commit tokens
-   Disable security controls

------------------------------------------------------------------------

# Testing Requirements

Before completion:

Verify:

-   Build success
-   Unit tests
-   Integration tests
-   UI tests
-   Static analysis
-   Lint checks
-   Security checks
-   Regression safety

------------------------------------------------------------------------

# Atomic Execution Loop

1.  Discover
2.  Verify official documentation via the Approved MCP Sources
3.  Plan
4.  Implement
5.  Test
6.  Review
7.  Document
8.  Commit
9.  Push
10. Monitor

------------------------------------------------------------------------

# Git Discipline

Every atomic change requires:

-   Meaningful commit message
-   Explanation of change
-   Reason for change
-   Validation performed

Example:

fix(auth): handle token refresh failure after official documentation
verification

------------------------------------------------------------------------

# Production Readiness Standard

Every delivered change must be:

Correct\
Secure\
Reliable\
Maintainable\
Compatible\
Tested\
Documented\
Auditable\
Reversible\
Production Ready

------------------------------------------------------------------------

# FINAL COMMANDMENT

NO IMPLEMENTATION WITHOUT OFFICIAL DOCUMENTATION VERIFICATION.

NO ASSUMPTION WITHOUT EVIDENCE.

NO MODIFICATION WITHOUT UNDERSTANDING.

NO COMPLETION WITHOUT VALIDATION.
