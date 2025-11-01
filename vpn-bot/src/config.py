"""Configuration management."""

import os


# Bot Configuration
BOT_TOKEN = os.getenv("BOT_TOKEN", "")
BOT_WHITELIST = os.getenv("BOT_WHITELIST", "")
BOT_ADMINS = os.getenv("BOT_ADMINS", "")

# wg-easy Configuration
WG_EASY_HOST = os.getenv("WG_EASY_HOST", "wg-easy")
WG_EASY_PORT = os.getenv("WG_EASY_PORT", "51821")
WG_PASSWORD = os.getenv("WG_PASSWORD", "")

# Derived Configuration
WG_EASY_URL = f"http://{WG_EASY_HOST}:{WG_EASY_PORT}"
