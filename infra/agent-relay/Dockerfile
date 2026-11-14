FROM python:3.12-slim
WORKDIR /app
COPY agent_relay ./agent_relay
RUN useradd --system --uid 10001 relay && mkdir /data && chown relay /data
USER relay
ENV AGENT_RELAY_DB=/data/agent-relay.db AGENT_RELAY_HOST=0.0.0.0 AGENT_RELAY_PORT=8765
EXPOSE 8765
HEALTHCHECK CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8765/healthz', timeout=3)"
ENTRYPOINT ["python3", "-m", "agent_relay"]
CMD ["serve"]
