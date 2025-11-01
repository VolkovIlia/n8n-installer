"""
Environment variables adapter for n8n-installer integration.
Maps n8n-installer environment variables to bot's expected format.
"""
import os
import sys

# Map n8n-installer variables to bot's expected variables
BOT_TOKEN = os.getenv("BOT_TOKEN")
WG_PASSWORD = os.getenv("WG_PASSWORD")
WG_EASY_HOST = os.getenv("WG_EASY_HOST", "wg-easy")
WG_EASY_PORT = os.getenv("WG_EASY_PORT", "51821")
BOT_WHITELIST = os.getenv("BOT_WHITELIST", "")
BOT_ADMINS = os.getenv("BOT_ADMINS", "")

# Set bot's expected variables
os.environ["TELEGRAM_TOKEN"] = BOT_TOKEN or ""
os.environ["SESSION_PASSWORD"] = WG_PASSWORD or ""

# Configure single server (SERVER1)
os.environ["SERVER1_KEY"] = "vpn"
os.environ["SERVER1_NAME"] = "VPN"
os.environ["SERVER1_URL"] = f"http://{WG_EASY_HOST}:{WG_EASY_PORT}"

# Map whitelist (combine BOT_WHITELIST and BOT_ADMINS)
allowed_users = []
if BOT_WHITELIST:
    allowed_users.extend(BOT_WHITELIST.split(","))
if BOT_ADMINS:
    allowed_users.extend(BOT_ADMINS.split(","))

# If no whitelist/admins specified, allow all users (empty ALLOWED_USERS)
os.environ["ALLOWED_USERS"] = ",".join(allowed_users) if allowed_users else ""

# Set DB directory
os.environ["DB_DIR"] = "db"

# Validate required variables
if not BOT_TOKEN:
    print("ERROR: BOT_TOKEN environment variable is required", file=sys.stderr)
    sys.exit(1)

if not WG_PASSWORD:
    print("ERROR: WG_PASSWORD environment variable is required", file=sys.stderr)
    sys.exit(1)

print(f"Environment adapter configured:")
print(f"  TELEGRAM_TOKEN: {BOT_TOKEN[:10]}...")
print(f"  SESSION_PASSWORD: ***")
print(f"  SERVER1_URL: http://{WG_EASY_HOST}:{WG_EASY_PORT}")
print(f"  ALLOWED_USERS: {os.environ['ALLOWED_USERS'] or '(all users)'}")
