---
name: protocol-compliance-review
description: Given a library/gem and a protocol spec URL, produce a structured compliance gap report covering wire format, required operations, field shapes, error codes, and test suite blind spots — with a prioritized fix list.
---

# Skill: Protocol Compliance Review

Use this skill to audit how well a codebase implements a versioned protocol specification. It reads the spec, reads the implementation source, cross-references them section by section, analyzes the test suite for structural blind spots, and produces a prioritized gap report saved to the session state folder.

Works for any protocol with a published spec — A2A, MCP, JSON-RPC, OpenAPI, gRPC, etc.

---

## Phase 0 — Gather Inputs

If not already provided, ask:

**Use `ask_user`:**
> "What is the library or gem to review? Provide a GitHub URL or local path."

Allow freeform.

**Use `ask_user`:**
> "What is the protocol spec URL? (e.g., a raw markdown URL, a proto file, or an OpenAPI spec)"

Allow freeform.

Store as `IMPL_SOURCE` and `SPEC_URL`.

Also ask for the spec version the implementation **claims** to target:

**Use `ask_user`:**
> "What version of the spec does the implementation claim to target? (e.g., 'A2A v1.0', 'MCP 2025-03-26')"

Allow freeform. Store as `CLAIMED_VERSION`.

---

## Phase 1 — Read the Spec

Fetch the spec in sections. Large specs require paginated fetching:

```
# Fetch 20KB at a time using start_index
# Identify the sections needed upfront rather than reading the whole spec
# Priority sections: operations/methods, data model/types, error codes, field naming conventions, transport headers, discovery/registration
```

**Key principle for proto-defined protocols (A2A, gRPC-based):**
The `.proto` file is the canonical normative source, not the markdown. JSON field names MUST be camelCase per ProtoJSON rules. Always locate and read the proto if one exists.

Build a mental (or written) checklist of requirements from the spec covering:
1. Required operations / methods (and their exact names)
2. Required data model fields (and their exact JSON names and types)
3. Enum value formats (e.g., SCREAMING_SNAKE_CASE per ProtoJSON)
4. Error codes and their canonical values
5. Transport conventions (Content-Type, version headers, response codes)
6. Discovery / registration mechanism (e.g., `/.well-known/agent.json`)
7. Streaming event payload shapes (if applicable)

---

## Phase 2 — Read the Implementation

For each concern area identified in Phase 1, locate and read the relevant source files in parallel:

- **Transport layer:** controllers, routers, route definitions
- **Serialization:** model serializers, `to_json`/`to_h` methods, response builders
- **Client:** any client library shipping with the implementation
- **Discovery:** well-known endpoint handlers, agent card / capability declaration
- **Error handling:** error classes, rescue blocks, error response builders
- **Streaming:** SSE / WebSocket handlers, event writers
- **Test suite:** unit specs, integration specs, external test toolchain configs (`package.json`, `requirements.txt`, etc.)

---

## Phase 3 — Build the Compliance Matrix

For each spec requirement, classify the implementation:

- ✅ **Compliant** — implementation matches spec requirement exactly
- ⚠️ **Partial** — present but with a deviation (cite what's wrong)
- ❌ **Non-compliant** — missing or incorrect (cite spec section + implementation location)

Organize findings into these areas:
1. Operations / methods (correct names, correct HTTP verbs/paths)
2. Data model field names and types
3. Enum value formats
4. Error codes
5. Transport conventions
6. Discovery / agent card shape
7. Streaming event shapes (if applicable)

For each ⚠️ or ❌ finding, record:
- **Spec requirement:** section + quoted requirement
- **Implementation:** file + line + what it actually does
- **Impact:** P0 (breaks interop with conformant clients), P1 (spec violation), P2 (missing optional feature)

---

## Phase 4 — Analyze the Test Suite

Ask three diagnostic questions about the test suite:

**Question 1 — Unit tests:**
Do the tests assert spec-required behavior, or do they assert the implementation's *current* (potentially wrong) behavior?
- Red flag: tests that were written after implementation and encode non-compliant behavior as `expected`
- Example: `expect(card["supportedInterfaces"]).to include("a2a")` — asserts the wrong shape, locking it in

**Question 2 — Integration tests:**
Are they closed-loop? (own client → own server)
- Red flag: the client and server are from the same codebase. Shared deviations cancel out.
- A conformant external client would expose deviations the internal client hides
- Flag any integration test that uses the library's own client to test the library's own server

**Question 3 — External test toolchain:**
Is the SDK or validator pinned to the same spec version as the implementation claims?
- Check `package.json`, `requirements.txt`, `Gemfile`, etc.
- Red flag: implementation claims spec v1.0 but test SDK is `^0.3.0`
- This is a common root cause of false-green test suites

---

## Phase 5 — Produce the Report

Determine the session state directory and output file path:

```bash
SESSION_DIR=$(ls -td ~/.copilot/session-state/*/ | head -1)
mkdir -p "$SESSION_DIR/files"
```

Derive a slug from the implementation name (e.g., `active-agent` → `active-agent-compliance-review.md`).

Write `$SESSION_DIR/files/<slug>-compliance-review.md` using this structure:

```markdown
# [Protocol] Compliance Review — `[implementation name]`

**Spec version reviewed:** [spec version + URL]
**Implementation reviewed:** [GitHub URL or path]
**Review date:** [date]

---

## TL;DR

[2-3 sentence summary of overall compliance posture]

**Compliance summary:**

| Area | Status |
|---|---|
| [area] | ✅ / ⚠️ / ❌ |

---

## Detailed Findings

### [Area name]

#### ✅ What's correct
- [finding with evidence]

#### ❌ Issues

**[Issue title]**
Spec requires: [quoted requirement + section]
Implementation: [file:line — what it does instead]
Impact: P0 / P1 / P2

---

## Why Didn't the Test Suite Catch This?

### [Test layer] — [root cause label]
[Explanation of the structural reason this test layer missed the violations]

---

## Summary: Prioritized Fix List

### P0 — Breaks interoperability with conformant clients
1. [fix]

### P1 — Spec violations affecting correctness
2. [fix]

### P2 — Missing operations / nice-to-have
3. [fix]
```

After writing, open the file in VS Code:

```bash
code "$SESSION_DIR/files/<slug>-compliance-review.md"
```

---

## Key Principles

- **Spec version alignment:** Always verify both the version the implementation *claims* and the version the *test toolchain* actually validates against. These are often different.
- **Closed-loop tests:** An implementation's own client testing its own server proves self-consistency, not spec conformance. True conformance requires a third-party client or schema validator.
- **Proto-defined protocols:** For A2A, gRPC, and similar: the `.proto` file is the normative source. JSON field names must follow ProtoJSON conventions (camelCase for fields, SCREAMING_SNAKE_CASE for enums).
- **Test root causes:** Distinguish "wrong behavior encoded as expected" (regression test problem — must fix both the implementation AND the test) from "no coverage" (coverage gap — add tests).
- **Fetch strategy:** Identify needed spec sections upfront. Fetch 20KB chunks by section name rather than paginating the whole spec linearly.
