# Hindsight development-memory setup

Configured at the owner's request on 2026-11-06. Hindsight serves coding agents working on MemoryOS. The app's runtime memory system remains unselected.

## Routing

- Project path: `/Users/eros/Dev/Eros_Projects/Eros_MemoryOS`.
- CLI project ID: `memoryos`.
- Memory bank: `project-memoryos`.
- Tag and observation scope: `project:memoryos`.
- Shared installation: `/Users/eros/Dev/Eros_Projects/Hindsight`.
- Local API: `http://127.0.0.1:8888`.
- Memory browser: `http://127.0.0.1:9999`; select `project-memoryos`.
- Bank-specific MCP endpoint: `http://127.0.0.1:8888/mcp/project-memoryos/`.
- Project MCP declaration: `.codex/config.toml`.
- Shared registry: `/Users/eros/Dev/Eros_Projects/Hindsight/config/projects.json`.
- Shared coding-agent config: `/Users/eros/.hindsight/coding-agent.json`, a link to the shared installation's `config/coding-agent.json`.

The exact project path maps to this bank. No other project bank is reused. A new session may be needed before new MCP tools become available. The project CLI works without an MCP refresh.

## What stays local and what leaves the Mac

The existing shared service stores its database and multilingual embedding model locally. Its configured extraction provider is `openai-codex`, which sends retained documentation and reflection queries to OpenAI through the separately authorized development setup. This consumes the configured provider's limits.

Therefore, this is a self-hosted development-memory service with external extraction. It is not proof of fully local AI, an iPhone installation, or supported subscription integration inside the planned app.

Only sanitized project documentation is approved for this workflow. Do not retain the owner's real conversations with other people or product data.

## Source allowlist

The shared registration indexes:

- `README.md`
- `AGENTS.md`
- `docs/**/*.md`
- `FULLSTACK.md`, if a future authorized task creates it

The three original `Project_Idea*.md` files are outside the allowlist. Their sanitized interpretation and hashes are in the new source/historical registers. Scripts, configuration, evidence JSON, raw chats, audio, credentials, and app data are also outside the allowlist.

A file containing `<!-- hindsight:ignore -->` on its own line is excluded. Do not widen the allowlist or enable raw retention to make a failed import appear complete.

## Commands

```sh
./scripts/memory recall --query 'What is the current MemoryOS product direction?'
./scripts/memory sync
./scripts/memory check
./scripts/memory status
```

The wrapper pins `--project memoryos`. It rejects a project override. The shared CLI otherwise defaults to another project, so always use this wrapper or an explicit `--project memoryos` argument.

`sync` submits changed allowlisted sources. `check` can submit changes and inspect their delivery state. A successful check needs a healthy API and zero pending/failed sources. `status` reads current delivery state without synchronizing files.

Use a focused recall after ingestion to verify that this bank returns useful project facts. A successful empty recall only confirms that the request worked; it does not establish searchable project content. Empty default knowledge pages are expected in this installation.

The shared watcher considers registered Markdown periodically. Do not start another watcher. Do not poll rapidly, blindly resubmit pending sources, or repeatedly retry a failed operation. Inspect the failure and use the shared explicit retry command only when the cause is understood.

## Preserved settings

Raw session retention remains off. Automatic seeding and codebase surveys remain off. Global opt-in and existing per-harness settings remain unchanged. Other projects' mappings and bank settings remain unchanged.

Markdown and current owner instructions remain authoritative. Extracted memories must preserve historical/proposed/confirmed/verified status.

## Verification evidence

See [documentation validation](../evidence/documentation-validation.json) and [memory delivery verification](../evidence/hindsight-verification.json). Evidence files are JSON and are not indexed by the Markdown watcher. They describe a dated snapshot, not a guarantee about future service state.

## Reversal

If the owner later requests disconnection, remove only the `memoryos` registry entry, this exact path mapping, this bank's coding-agent settings, and the project MCP declaration. Review the watcher's source-withdrawal behavior before changing registered source paths.

Disconnection does not delete existing bank data. Bank deletion needs an explicit owner request. Preserve every other project and global setting.
