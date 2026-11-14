# PoC only (design 0002, work item 2). Not production code.
# Mock relay: per-agent queue with long-poll. GET /wait?agent=a&timeout=s, POST /send?agent=a (body = summary line)
import http.server, threading, time, urllib.parse, collections, sys
Q = collections.defaultdict(list); C = threading.Condition()
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        agent, t = q["agent"][0], float(q.get("timeout", ["25"])[0])
        end = time.time() + t
        with C:
            while not Q[agent] and time.time() < end:
                C.wait(end - time.time())
            msgs, Q[agent] = Q[agent], []
        body = "\n".join(msgs).encode()
        self.send_response(200 if msgs else 204); self.end_headers(); self.wfile.write(body)
    def do_POST(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        data = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode()
        with C:
            Q[q["agent"][0]].append(data); C.notify_all()
        self.send_response(202); self.end_headers()
http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
