---
name: polish-writing
description: Remove the AI tone from Korean or English prose — product and developer-site copy, API docs, README, docs/, design docs, PR and issue text — and make it concrete, consistent and human. Use whenever you write or revise text people will read (pages, headlines, buttons, error messages, documentation), or when asked to 다듬어, 윤문, AI 티 빼기, polish, rewrite or edit copy.
paths:
  - "**/*.md"
  - "**/*.mdx"
  - "**/*.html"
  - "**/locales/**"
  - "**/i18n/**"
---

# Polish writing

The team standard is `docs/17-writing-and-design-standards.md`. A deterministic check runs after every edit
(`style_check.py`, rules in `style/rules.toml`); its findings come back to you as context. This skill covers what a
regex cannot judge.

## Hard limits (never break these while polishing)

- Do not add facts, numbers, names, quotes, customers or claims that are not in the source. If copy needs a number
  you do not have, leave `[숫자 필요]` / `[TODO: metric]` and say so.
- Leave code, commands, paths, identifiers, link targets, API names, units and quoted text exactly as they are.
- Keep the author's meaning and technical precision; cut words, not content.

## Order of work

1. **Reader and job.** Who reads this and what must they do or decide after? Product page: what the product does
   for them. API docs: how to call it and what can go wrong. Team doc: what to do and why.
2. **One speech level per surface.** Team default 해요체 for product UI, sites and team docs; 합니다체 only where the
   surface already uses it consistently (e.g. legal text). Lists and table cells may be noun phrases (개조식).
   English: plain, sentence-case headings.
3. **Concrete over impressive.** Replace every adjective of praise with what it means: a number with a unit
   (`1 ms`, `64 KB`, `50,000원`), a condition, or an action. If you cannot, delete the adjective.
4. **Headlines say the user outcome; buttons say what happens next** (`API 키 발급`, `결제하기`, `Save changes`),
   never `시작하기`/`Submit` for everything. Errors say what happened and what to do, without apologizing.
5. **Cut the scaffolding:** run-ups (`이제 ~을 알아보겠습니다`, `Let's dive in`), summaries of what was just said
   (`결론적으로`, `In summary`), significance inflation (`시사하는 바가 크다`, `pivotal`), contrast theater
   (`단순한 X를 넘어`, `It's not X, it's Y`), forced triplets, rhetorical questions, emoji markers, decorative bold.
6. **Natural Korean.** Prefer verbs to nominalizations (`삭제 작업을 수행합니다` → `삭제해요`), active voice with a real
   subject, and Korean particles over translationese (`~을 통해` → `~로`, `~에 있어서` → `~에서`, `~을 가지고 있다` →
   `~이 있다`). One term per concept; expand an abbreviation once on first use, e.g. `SSR(Server-Side Rendering)`.
7. **Read it aloud.** If a sentence carries two ideas, split it. If a paragraph's first sentence repeats the heading,
   delete it.

## Output

When asked to polish existing text, return the revised text, then at most 5 bullets naming the biggest changes. When
writing new text, just write it to this standard. Fix every `error` from the style check; for a `warning`, fix it or
keep it on purpose. To quote a bad example on purpose, mark the line with `style-ignore`.

Sources and licenses: `THIRD_PARTY_NOTICES.md` in this plugin.
