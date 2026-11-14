"""Checks a message must pass before the relay stores it."""

import re

SECRET_PATTERNS = [
    ("private key", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("AWS access key", re.compile(r"\b(AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("GitHub token", re.compile(r"\b(gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{40,})\b")),
    ("Slack token", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b")),
    ("Anthropic API key", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}")),
    ("OpenAI-style API key", re.compile(r"\bsk-(proj-)?[A-Za-z0-9_-]{32,}")),
    ("Google API key", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("JWT", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
    ("password assignment", re.compile(r"(?i)\b(password|passwd|secret|api[_-]?key)\s*[:=]\s*['\"][^'\"\s]{8,}['\"]")),
]


class Rejected(ValueError):
    """The message was refused; the text says why and is safe to show to the sender."""


def check(text: str, max_bytes: int) -> None:
    size = len(text.encode("utf-8"))
    if size > max_bytes:
        raise Rejected(
            f"message is {size} bytes; the limit is {max_bytes}. Send a summary and file references instead."
        )
    for name, pattern in SECRET_PATTERNS:
        if pattern.search(text):
            raise Rejected(f"message looks like it contains a secret ({name}); remove it and send again.")
