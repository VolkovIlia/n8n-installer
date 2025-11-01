#!/usr/bin/env python3
"""
Main entry point for VPN Telegram bot.
Sets up environment and launches bot.
"""
import sys

# Import and run environment adapter first
try:
    import env_adapter
except Exception as e:
    print(f"ERROR: Failed to configure environment: {e}", file=sys.stderr)
    sys.exit(1)

# Now import and run the bot
try:
    import bot
    bot.main()  # Call the main function
except Exception as e:
    print(f"ERROR: Failed to start bot: {e}", file=sys.stderr)
    sys.exit(1)
