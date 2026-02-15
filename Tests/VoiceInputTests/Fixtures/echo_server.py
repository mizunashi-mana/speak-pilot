"""Mock STT server for testing ProcessRunner.

Reads JSON lines from stdin, responds with corresponding events on stdout.
Logs to stderr.
"""

import json
import sys


def main():
    # Emit ready event
    sys.stdout.write(json.dumps({"type": "ready"}) + "\n")
    sys.stdout.flush()
    sys.stderr.write("INFO: Mock server ready\n")
    sys.stderr.flush()

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            cmd = json.loads(line)
        except json.JSONDecodeError:
            continue

        cmd_type = cmd.get("type")
        if cmd_type == "shutdown":
            break
        elif cmd_type == "start":
            sys.stdout.write(json.dumps({"type": "speech_started"}) + "\n")
            sys.stdout.write(
                json.dumps(
                    {"type": "transcription", "text": "テスト", "is_final": True}
                )
                + "\n"
            )
            sys.stdout.write(json.dumps({"type": "speech_ended"}) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
