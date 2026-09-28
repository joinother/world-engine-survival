#!/usr/bin/env python3
"""Small stdlib-only JSON-RPC client for the running World Engine demo."""

from __future__ import annotations

import argparse
import json
import socket
import sys
from typing import Any


def rpc(method: str, params: dict[str, Any], host: str, port: int) -> dict[str, Any]:
    request = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
    with socket.create_connection((host, port), timeout=3.0) as connection:
        connection.sendall((json.dumps(request, ensure_ascii=False) + "\n").encode("utf-8"))
        response = connection.makefile("rb").readline()
    if not response:
        raise RuntimeError("游戏没有返回响应")
    return json.loads(response.decode("utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser(description="World Engine JSON-RPC CLI")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=9555)
    parser.add_argument("--role", choices=("player", "director", "admin"), default="player")
    subparsers = parser.add_subparsers(dest="action", required=True)
    subparsers.add_parser("state")
    subparsers.add_parser("attack")
    observe = subparsers.add_parser("observe")
    observe.add_argument("--radius", type=float, default=12.0)
    subparsers.add_parser("content")
    advance = subparsers.add_parser("advance")
    advance.add_argument("minutes", type=float)
    event = subparsers.add_parser("event")
    event.add_argument("event_id")
    snapshot = subparsers.add_parser("snapshot")
    snapshot.add_argument("name")
    rollback = subparsers.add_parser("rollback")
    rollback.add_argument("name")
    subparsers.add_parser("snapshots")
    command = subparsers.add_parser("command")
    command.add_argument("text", nargs="+")

    args = parser.parse_args()
    params: dict[str, Any] = {"role": args.role}
    if args.action == "state":
        method = "world.state"
    elif args.action == "attack":
        method = "player.attack"
    elif args.action == "observe":
        method = "player.observe"
        params["radius"] = args.radius
    elif args.action == "content":
        method = "world.content"
    elif args.action == "advance":
        method = "time.advance"
        params["minutes"] = args.minutes
    elif args.action == "event":
        method = "event.start"
        params["id"] = args.event_id
    elif args.action == "snapshot":
        method = "world.snapshot"
        params["name"] = args.name
    elif args.action == "rollback":
        method = "world.rollback"
        params["name"] = args.name
    elif args.action == "snapshots":
        method = "world.snapshots"
    else:
        method = "world.command"
        params["command"] = " ".join(args.text)

    try:
        response = rpc(method, params, args.host, args.port)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"连接失败：{error}", file=sys.stderr)
        return 1
    print(json.dumps(response, ensure_ascii=False, indent=2))
    return 0 if "error" not in response else 2


if __name__ == "__main__":
    raise SystemExit(main())
