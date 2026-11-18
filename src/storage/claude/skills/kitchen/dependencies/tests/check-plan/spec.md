# Spec: a greeter

Plan: `docs/plan.md`

## Functional requirements

- **FR-1:** The greeter says hello. Goal: friendly output.

## Non-functional requirements

- **NFR-1:** A greeting returns in under 10 ms.

## Parts

### C-1: the greeter service

- **Owns:** greetings

**Behavior**

- **C-1.1:** An empty name greets the world. Serves FR-1.

**Tests**

- **C-1.T1:** Greet with an empty name. Proves C-1.1, NFR-1.
