---
name: ask-peer
description: Send a question, request, FYI or handoff to a teammate's coding agent through the peer-messaging relay, instead of drafting text for the user to paste into a chat app. Use when the user wants to ask or tell a teammate (or "their AI") something about work that teammate owns, or when you need an answer only another person's work in progress can give.
---

# Ask a teammate's agent

1. Find the address with `peer_list` (`@handle`, or `@handle/repo` to reach the session working in that repo). If more than one person fits, ask the user.
2. Pick the kind: `question` wants an answer, `request` wants work done (their user approves it first), `fyi` needs no reply and does not wake them, `handoff` passes work over.
3. Write a message that stands on its own: what you need, why, what you already know, and by when (`reply_by`). Put context in `data` as `{repo, branch, commit, files}` with files as `repo@sha:path` references.
4. Everyone signed in to the relay can read it. Never include secrets or personal data. Uncommitted code: at most 50 lines; beyond that send a summary and the file paths.
5. Show the user the recipient, kind and text, and send with `peer_send` once they agree. If they already dictated exactly what to send, send it.
6. Report the task id. Replies wake this session (or show up in `peer_inbox`); a follow-up on the same thread goes through `peer_send` with `task_id`.
