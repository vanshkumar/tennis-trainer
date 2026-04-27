# Docs

This directory is the repository knowledge map.

The repo is still small, so the goal is not to create a heavy documentation system. The goal is to make the existing source-of-truth material easier for agents and humans to find without bloating `AGENTS.md`.

For a fresh session, use `RAMPUP.md` after reading this file.

## Read In This Order

1. `../AGENTS.md`
   Repository rules, coding conventions, and agent-specific constraints.
2. `RAMPUP.md`
   Fast orientation path for a fresh session, including current-reality pointers and known frictions.
3. `../ARCHITECTURE.md`
   Current runtime structure, component boundaries, and where logic lives.
4. `../README.md`
   User-facing product framing.
5. `../PRD.MD`
   Product behavior and implementation expectations.
6. `plans/active/README.md`
   Active execution brief index.
7. `references/README.md`
   Technical references and model-specific notes.

## Structure

- `product/`
  Product-facing specs and links to the current source-of-truth files.
- `plans/`
  Active and future execution-plan pointers.
- `references/`
  Technical/reference material that is useful during implementation.
- `RAMPUP.md`
  Fresh-session onboarding path.

## Conventions

- Keep top-level docs short and navigable.
- Prefer adding new long-form knowledge under `docs/` instead of expanding `AGENTS.md`.
- Keep one clear source of truth for each topic; link to it rather than duplicating it.
- Only add durable documentation artifacts that remove repeated confusion or repeated rework. Avoid process documents that need their own maintenance loop.
- If a root `*_IMPL.md` file exists, treat it as a temporary active handoff brief and link to it from `docs/plans/active/README.md`.
- When a temporary plan is completed, either delete it or move its durable lessons into a stable doc under `docs/`.

## Current Source Of Truth

- Product framing: `../README.md`
- Product spec: `../PRD.MD`
- Architecture: `../ARCHITECTURE.md`
- GridTrackNet reference: `../GRIDTRACKNET_COREML.md`
- Ramp-up guide: `RAMPUP.md`
