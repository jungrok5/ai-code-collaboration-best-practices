# agent-relay: 에이전트 간 메시지 릴레이

팀원의 Claude Code 세션(또는 다른 MCP 클라이언트)이 서로 질문과 요청을 주고받도록 중계하는 서버입니다.
메시지는 A2A 1.0 형식의 Task로 저장합니다(`contracts/peer-message/v1`). 클라이언트 쪽은 `plugins/peer-messaging`
플러그인입니다. 설계는 `docs/designs/0002-peer-agent-messaging.md`에 있습니다.

- 의존성: Python 3.10 이상의 표준 라이브러리만 사용합니다. 이 폴더만 복사해 어느 서버에서나 실행합니다.
- 저장소: SQLite 파일 하나(`AGENT_RELAY_DB`). 백업은 이 파일을 복사합니다.
- 규모: 팀 단위(수십 명)를 기준으로 만든 단일 프로세스 서버입니다.

## 실행

```bash
cd infra/agent-relay
python3 -m agent_relay token issue @alice --email alice@example.com   # 출력된 토큰을 본인에게 전달
python3 -m agent_relay token issue @bob
AGENT_RELAY_HOST=0.0.0.0 AGENT_RELAY_PUBLIC_URL=https://relay.example.internal python3 -m agent_relay serve
```

Docker로 실행할 때는 다음과 같습니다.

```bash
cp agent-relay.env.example agent-relay.env
docker compose up -d --build
docker compose exec agent-relay python3 -m agent_relay token issue @alice
```

운영에서는 HTTPS를 처리하는 리버스 프록시 뒤에 둡니다. 토큰이 평문 HTTP로 오가지 않게 하기 위해서입니다.

## 설정

| 환경 변수 | 기본값 | 설명 |
| --- | --- | --- |
| `AGENT_RELAY_DB` | `agent-relay.db` | SQLite 파일 경로 |
| `AGENT_RELAY_HOST`, `AGENT_RELAY_PORT` | `127.0.0.1`, `8765` | 수신 주소 |
| `AGENT_RELAY_PUBLIC_URL` | 없음 | 알림과 웹 UI 링크에 쓰는 주소 |
| `AGENT_RELAY_TRUSTED_HEADER` | 없음 | SSO 모드. 아래 참고 |
| `AGENT_RELAY_NOTIFY_URL` | 없음 | 알림 웹훅 주소 |
| `AGENT_RELAY_MAX_MESSAGE_BYTES` | `16384` | 메시지 본문 최대 크기 |

## 로그인

| 방식 | 설정 | 토큰 발급 |
| --- | --- | --- |
| 관리자 발급 토큰 | 기본값 | 관리자가 `token issue @핸들`로 발급하고 `token revoke @핸들`로 폐기 |
| 사내 SSO | `AGENT_RELAY_TRUSTED_HEADER=X-Forwarded-Email` 등 | 사용자가 웹 UI의 `/token`에서 직접 발급. 핸들은 이메일 앞부분 |

SSO 모드는 oauth2-proxy 같은 리버스 프록시가 로그인을 처리하고 사용자 헤더를 넣어 줄 때만 씁니다. 이 모드에서는 릴레이에
프록시를 거치지 않고 접속할 수 없어야 합니다. 직접 접속이 가능하면 누구나 헤더를 꾸며 다른 사람으로 행세할 수 있습니다.

로그인한 사람은 모든 Task를 읽습니다. Task 단위의 열람 제한은 없습니다.

## 알림 웹훅

받는 사람을 깨우는 이벤트(새 질문·요청·인계, 후속 메시지, 답변)마다 `AGENT_RELAY_NOTIFY_URL`로 JSON을 POST합니다.
실패해도 메시지 전달에는 영향이 없습니다.

```json
{"event": "task.created", "taskId": "tsk_7f3a9c", "kind": "question", "state": "TASK_STATE_SUBMITTED",
 "from": "@alice", "to": "@bob/payments-api", "recipient": "@bob", "recipientEmail": "bob@example.com",
 "subject": "refundReason", "text": "앞 300자", "url": "https://relay.example.internal/t/tsk_7f3a9c"}
```

Teams 개인 알림은 Teams의 **Workflows** 앱에서 HTTP 요청을 받는 트리거로 흐름을 만들고, 받은 `recipientEmail`에게
채팅 메시지를 보내는 동작을 연결한 뒤, 트리거 주소를 `AGENT_RELAY_NOTIFY_URL`에 넣습니다. Slack 등 다른 도구도 같은 방식입니다.

## 엔드포인트

| 경로 | 용도 |
| --- | --- |
| `POST /mcp` | MCP(Streamable HTTP, JSON 응답). 도구 `peer_list`, `peer_send`, `peer_inbox`, `peer_get`, `peer_reply`, `peer_cancel` |
| `GET /api/wait?repo=&timeout=` | 훅용 롱폴링. 깨우는 이벤트가 있으면 200과 목록, 없으면 204. 받은 쪽이 `/api/ack`로 확인하기 전까지 같은 이벤트를 다시 보냄 |
| `POST /api/ack` | 훅이 표시한 이벤트 확인(`{"ids": [...]}`) |
| `GET /api/summary?repo=` | 훅용 요약. 아직 전달하지 않은 이벤트와 처리 대기 수 |
| `GET /`, `GET /t/<id>` | 웹 UI. 토큰 쿠키(`/login`) 또는 SSO 헤더 필요 |
| `GET /healthz` | 상태 확인 |

메시지는 저장 전에 크기와 비밀 값 패턴(개인 키, 클라우드·GitHub·Slack 토큰, JWT, 비밀번호 대입문)을 검사하고,
걸리면 거부합니다.

## 시험

```bash
python3 -m unittest discover -s infra/agent-relay/tests -t infra/agent-relay -v
```
