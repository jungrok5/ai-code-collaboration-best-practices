---
description: A plain code bug fix must not pull in the writing or UI polish skills.
tags: [writing, ui, negative, smoke]
runs: 3
max_turns: 6
allowed_tools: [Read, Glob, Grep, Skill]
---

This Python function should add two numbers but returns the wrong result. What's the fix?

```python
def add(a, b):
    return a - b
```
