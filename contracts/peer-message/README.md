# peer-message 계약

Claude Code 세션(또는 다른 MCP 클라이언트) 사이에서 주고받는 Task의 형식입니다. 설계는
`docs/designs/0002-peer-agent-messaging.md`에 있습니다.

| 파일 | 내용 |
| --- | --- |
| `v1/task.schema.json` | JSON Schema(2020-12). A2A 1.0 Task의 ProtoJSON 표기(`TASK_STATE_*`, `ROLE_*`, Part는 `text`·`url`·`data` 중 하나) |
| `v1/examples/*.json` | 스키마를 통과해야 하는 예시 |
| `v1/validate.py` | 예시 또는 지정한 파일 검증. `jsonschema` 패키지 필요 |

```bash
uv run --no-project --with jsonschema==4.26.0 python contracts/peer-message/v1/validate.py
```

팀 확장 필드는 `metadata["peer/v1"]`에 둡니다(`kind`, `from`, `to`, `subject`, `replyBy`, `createdAt`, `updatedAt`).
확장 필드를 깨는 변경은 `peer/v2` 키로 추가하고, 소비자가 옮길 때까지 두 키를 함께 받습니다.
