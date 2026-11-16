# Project Agent Instructions

## General Rules

- Read the existing architecture before making changes.
- Respect established coding conventions.
- Preserve existing functionality.
- Avoid duplicate implementations.
- Use strict TypeScript where applicable.
- Never modify environment secrets.
- Never execute destructive database operations.
- Never commit or push without authorization.

## Multi-Agent Protocol

- Coordinator owns task distribution and integration.
- Frontend owns frontend implementation.
- Backend owns backend implementation.
- QA owns testing and review.
- Avoid simultaneous edits to the same files.
- Coordinate API contracts before dependent changes.
- Report modified files and test results.
- Review all changes before integration.

## Completion

A task is complete only after:

- Implementation is reviewed.
- Relevant tests are executed.
- Type checks pass where available.
- Outstanding issues are documented.
