"""Entry point: python -m speak_pilot_stt_stdio"""

import logging
import sys

from .service import Service


def main() -> None:
    logging.basicConfig(
        stream=sys.stderr,
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    service = Service()
    service.run()


if __name__ == "__main__":
    main()
