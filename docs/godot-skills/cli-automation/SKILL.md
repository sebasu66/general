---
name: godot-cli-automation
description: Use for GitHub-to-local execution, engine inspection, script validation, test runs and proof capture.
---

# Godot CLI automation

The local machine is an execution worker. GitHub remains the source of truth.

## Workflow

```text
agent commits to GitHub
-> local worker detects/pulls commit
-> validates project
-> runs tests
-> executes bounded prototype scenario
-> captures logs/telemetry/screenshots/video
-> uploads/commits result artifacts as configured
-> agent reads results
```

Do not silently edit the local working copy as the authoritative implementation.

## Plain Godot CLI first

Always discover the executable/version instead of assuming a path or version.

Useful categories of operations:

- print engine version;
- import resources headlessly;
- start project headlessly for validation;
- run a `SceneTree` tool/test script;
- run automated tests;
- run deterministic capture.

Exact flags must be checked against the locally installed Godot version before creating permanent automation.

## CLI-Anything Godot

The reviewed `cli-anything-godot` harness can provide structured agent-friendly commands. At the reviewed revision it supports operations such as:

```bash
cli-anything-godot --json engine status
cli-anything-godot engine version
cli-anything-godot --json -p <project> project info
cli-anything-godot --json -p <project> project scenes
cli-anything-godot --json -p <project> project scripts
cli-anything-godot --json -p <project> project resources
cli-anything-godot -p <project> project reimport
cli-anything-godot -p <project> script validate scripts/example.gd
cli-anything-godot -p <project> script run tools/example.gd
```

Install/use it only after checking the local environment. If it is absent or blocked, fall back to Godot's native CLI rather than blocking the experiment.

## Godogen ideas worth reusing

Godogen's strongest fit with our methodology is its **proof over claims** approach:

- detect installed toolchain versions;
- keep import/startup clean;
- run the actual game;
- use a deterministic scripted presentation/test scenario;
- capture motion over time, not just a compile result;
- inspect the visual proof before declaring success.

Its upstream Godot guide is C#/.NET-specific. Do not copy its language/build assumptions into this GDScript prototype unless we explicitly choose C# later.

## Monigote

The existing local monigote/AI local-access agent can be used to:

- pull/sync the requested branch;
- execute commands;
- launch Godot visibly when interactive observation is required;
- collect logs;
- retrieve generated screenshots/results.

Prefer machine-readable result files in addition to console text.

## Failure behavior

Automation should:

- stop on parse/test/startup errors;
- preserve the failing log;
- report the exact command and exit code;
- time out bounded runtime tests;
- avoid infinite retry loops;
- never claim visual success if capture failed.

## Source basis

Adapted from CLI-Anything `cli-anything-godot`, Godogen's Godot guide, and the repository workflow requested for this project. See `../README.md`.