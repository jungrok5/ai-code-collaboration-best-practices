---
description: A generic AI-looking hero section should be reworked with the team UI standard.
tags: [ui, smoke]
runs: 3
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

<!-- style-ignore-file -->
Redis 같은 인메모리 DB 제품 소개 페이지의 첫 화면이야. AI가 만든 티가 나는데 다듬어 줘. 다듬은 HTML(Tailwind) 코드 블록 하나만 채팅으로 주고, 바꾼 점 설명은 붙이지 마.

```html
<meta name="viewport" content="width=device-width, user-scalable=no">
<section class="text-center py-32 bg-gradient-to-r from-indigo-500 via-purple-500 to-pink-500">
  <span class="rounded-full px-3 py-1 bg-white/20 backdrop-blur">New ✨ Now in beta</span>
  <h1 class="text-6xl font-bold bg-clip-text text-transparent bg-gradient-to-r from-white to-purple-200">🚀 Unlock the Power of Data</h1>
  <p>Supercharge your apps with our revolutionary, blazing-fast database.</p>
  <button class="rounded-2xl shadow-2xl transition-all animate-bounce outline-none">Get Started →</button>
  <p>Trusted by 10,000+ teams ★★★★★</p>
</section>
```

제품 사실: 읽기 지연 1 ms 미만(p99, 단일 노드 벤치마크), 명령 예시는 `SET user:1 "kim"` / `GET user:1`.
