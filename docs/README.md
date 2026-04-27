# Docs

This directory is the repository knowledge map.

The repo is still small, so the goal is not to create a heavy documentation system. The goal is to make the existing source-of-truth material easier for agents and humans to find without bloating `AGENTS.md`.

## Read In This Order

1. `../AGENTS.md`
   Repository rules, coding conventions, and agent-specific constraints.
2. `../ARCHITECTURE.md`
   Current runtime structure, component boundaries, and where logic lives.
3. `../README.md`
   User-facing product framing.
4. `../PRD.MD`
   Product behavior and implementation expectations.
5. `plans/active/README.md`
   Active execution brief index.
6. `references/README.md`
   Technical references and model-specific notes.

## Structure

- `product/`
  Product-facing specs and links to the current source-of-truth files.
- `plans/`
  Active and future execution-plan pointers.
- `references/`
  Technical/reference material that is useful during implementation.

## Conventions

- Keep top-level docs short and navigable.
- Prefer adding new long-form knowledge under `docs/` instead of expanding `AGENTS.md`.
- Keep one clear source of truth for each topic; link to it rather than duplicating it.
- If a root `*_IMPL.md` file exists, treat it as a temporary active handoff brief and link to it from `docs/plans/active/README.md`.
- When a temporary plan is completed, either delete it or move its durable lessons into a stable doc under `docs/`.

## Current Source Of Truth

- Product framing: `../README.md`
- Product spec: `../PRD.MD`
- Architecture: `../ARCHITECTURE.md`
- Active implementation brief: `../SERVE_PIVOT_IMPL.md`
- GridTrackNet reference: `../GRIDTRACKNET_COREML.md`
