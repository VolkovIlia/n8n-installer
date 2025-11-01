"""VPN Telegram Bot - Main Entry Point."""

import sys
from telegram.ext import Application, CommandHandler
from .config import BOT_TOKEN, WG_EASY_URL, WG_PASSWORD
from .adapters import (
    WireGuardAPIAdapter,
    TelegramBotAdapter,
    QRCodeAdapter,
    StdoutAdapter
)
from .handlers import COMMAND_HANDLERS


def main() -> None:
    """Main bot initialization."""
    # Validate config (early return)
    if not BOT_TOKEN:
        print("ERROR: BOT_TOKEN not set", file=sys.stderr)
        sys.exit(1)

    if not WG_PASSWORD:
        print("ERROR: WG_PASSWORD not set", file=sys.stderr)
        sys.exit(1)

    # Mount adapters (Hurd settrans pattern)
    logger = StdoutAdapter()
    vpn_provider = WireGuardAPIAdapter(
        base_url=WG_EASY_URL,
        password=WG_PASSWORD
    )
    messaging = TelegramBotAdapter(bot_token=BOT_TOKEN)
    qr_generator = QRCodeAdapter()

    logger.log("info", "Starting VPN bot")
    logger.log("info", f"wg-easy URL: {WG_EASY_URL}")

    # Create Telegram application
    app = Application.builder().token(BOT_TOKEN).build()

    # Register command handlers (table-driven)
    for command, handler_class in COMMAND_HANDLERS.items():
        # Instantiate handler with dependencies
        if command == 'start':
            handler = handler_class(messaging, logger)
        elif command == 'request':
            handler = handler_class(
                vpn_provider, messaging, qr_generator, logger
            )
        elif command == 'revoke':
            handler = handler_class(vpn_provider, messaging, logger)
        elif command == 'status':
            handler = handler_class(vpn_provider, messaging, logger)
        else:
            continue

        # Register command
        app.add_handler(CommandHandler(command, handler.handle))
        logger.log("info", f"Registered handler: /{command}")

    # Start bot (polling mode for MVP)
    logger.log("info", "Bot started - polling for updates")
    app.run_polling(allowed_updates=['message'])


if __name__ == "__main__":
    main()
