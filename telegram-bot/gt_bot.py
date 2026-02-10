#!/usr/bin/env python3
"""Gas Town Telegram Bot — mobile interface to gts/bd commands."""

import asyncio
import json
import logging
import os
import subprocess
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from telegram import InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.constants import ParseMode
from telegram.ext import (
    Application,
    CallbackQueryHandler,
    CommandHandler,
    ContextTypes,
)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

load_dotenv()

BOT_TOKEN = os.environ["TELEGRAM_BOT_TOKEN"]
ALLOWED_CHAT_IDS = {
    int(cid.strip())
    for cid in os.environ.get("TELEGRAM_CHAT_ID", "").split(",")
    if cid.strip()
}
TOWN_ROOT = os.environ.get("GT_TOWN_ROOT", "/home/gastown/antik")
GT_BIN = os.environ.get("GT_BIN", "gt")
BD_BIN = os.environ.get("BD_BIN", "bd")
POLL_INTERVAL = int(os.environ.get("POLL_INTERVAL", "120"))
STATE_FILE = Path(os.environ.get("STATE_FILE", str(Path.home() / ".gt-bot-state.json")))

logging.basicConfig(
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
    level=logging.INFO,
)
log = logging.getLogger("gt-bot")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def authorized(func):
    """Decorator — reject messages from unknown chat IDs."""
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        if update.effective_chat.id not in ALLOWED_CHAT_IDS:
            await update.message.reply_text("Unauthorized.")
            return
        return await func(update, context)
    wrapper.__name__ = func.__name__
    return wrapper


def run_cmd(args: list[str], timeout: int = 30) -> str:
    """Run a shell command and return stdout (or stderr on failure)."""
    env = os.environ.copy()
    env["NO_COLOR"] = "1"
    try:
        result = subprocess.run(
            args,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=TOWN_ROOT,
            env=env,
        )
        output = result.stdout.strip() or result.stderr.strip()
        return output or "(no output)"
    except subprocess.TimeoutExpired:
        return "Command timed out."
    except Exception as exc:
        return f"Error: {exc}"


def gt(*args: str, timeout: int = 30) -> str:
    return run_cmd([GT_BIN, *args], timeout=timeout)


def bd(*args: str, timeout: int = 30) -> str:
    return run_cmd([BD_BIN, *args], timeout=timeout)


def truncate(text: str, limit: int = 4000) -> str:
    """Telegram messages max 4096 chars. Truncate with notice."""
    if len(text) <= limit:
        return text
    return text[: limit - 30] + "\n\n… (truncated)"


def escape_md(text: str) -> str:
    """Minimal Markdown-safe escaping for monospace blocks."""
    return text.replace("`", "'")


def mono(text: str) -> str:
    """Wrap text in a Markdown code block."""
    return f"```\n{escape_md(truncate(text))}\n```"


def try_parse_json(raw: str):
    """Try to parse JSON, return None on failure."""
    try:
        return json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        return None


# ---------------------------------------------------------------------------
# Formatters — pretty output from JSON where available
# ---------------------------------------------------------------------------


def fmt_status(raw: str) -> str:
    data = try_parse_json(raw)
    if not data:
        return mono(raw)

    lines = [f"🏭 *{data.get('name', '?')}*\n"]
    overseer = data.get("overseer", {})
    if overseer.get("unread_mail"):
        lines.append(f"📬 Overseer unread mail: {overseer['unread_mail']}")

    agents = data.get("agents", [])
    if agents:
        lines.append("\n*Agents:*")
        for a in agents:
            icon = "🟢" if a.get("running") else "⚫"
            state = a.get("state", "?")
            unread = f" 📬{a['unread_mail']}" if a.get("unread_mail") else ""
            lines.append(f"  {icon} `{a['name']}` — {state}{unread}")

    rigs = data.get("rigs", [])
    if rigs:
        lines.append("\n*Rigs:*")
        for r in rigs:
            pcount = r.get("polecat_count", 0)
            lines.append(f"  🔧 `{r['name']}` — {pcount} polecats")

    return "\n".join(lines)


def fmt_mail(raw: str) -> str:
    data = try_parse_json(raw)
    if not data:
        return mono(raw)
    if not data:
        return "📭 Inbox empty."

    lines = [f"📬 *Inbox* ({len(data)} messages)\n"]
    for m in data[:15]:  # show latest 15
        read_icon = "  " if m.get("read") else "🔴"
        mid = m.get("id", "?")
        subj = m.get("subject", "(no subject)")
        sender = m.get("from", "?")
        lines.append(f"{read_icon} `{mid}` from `{sender}`\n    {subj}")
    if len(data) > 15:
        lines.append(f"\n… and {len(data) - 15} more")
    return "\n".join(lines)


def fmt_ready(raw: str) -> str:
    data = try_parse_json(raw)
    if not data:
        return mono(raw)
    if not data:
        return "✅ No issues ready — all clear."

    lines = [f"📋 *Ready issues* ({len(data)})\n"]
    for issue in data[:20]:
        iid = issue.get("id", "?")
        title = issue.get("title", "(untitled)")
        prio = issue.get("priority", "?")
        lines.append(f"  `{iid}` P{prio} — {title}")
    if len(data) > 20:
        lines.append(f"\n… and {len(data) - 20} more")
    return "\n".join(lines)


def fmt_convoys(raw: str) -> str:
    data = try_parse_json(raw)
    if not data:
        return mono(raw)
    if not data:
        return "🚚 No active convoys."

    lines = [f"🚚 *Convoys* ({len(data)})\n"]
    for c in data[:15]:
        cid = c.get("id", "?")
        title = c.get("title", "(untitled)")
        status = c.get("status", "?")
        lines.append(f"  `{cid}` [{status}] {title}")
    return "\n".join(lines)


def fmt_polecats(raw: str) -> str:
    data = try_parse_json(raw)
    if not data or data == "null":
        return "🐾 No active polecats."
    if isinstance(data, str):
        return mono(data)

    lines = [f"🐾 *Polecats* ({len(data)})\n"]
    for p in data[:20]:
        name = p.get("name", "?")
        rig = p.get("rig", "?")
        status = p.get("status", "?")
        bead = p.get("bead", "")
        bead_str = f" → `{bead}`" if bead else ""
        lines.append(f"  `{rig}/{name}` [{status}]{bead_str}")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Command handlers — read-only
# ---------------------------------------------------------------------------


@authorized
async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    await update.message.reply_text(
        f"🏭 Gas Town Bot ready.\n\n"
        f"Your chat ID: `{chat_id}`\n\n"
        f"Use /help to see available commands.",
        parse_mode=ParseMode.MARKDOWN,
    )


@authorized
async def cmd_help(update: Update, context: ContextTypes.DEFAULT_TYPE):
    text = (
        "*Gas Town Bot Commands*\n\n"
        "*Read-only:*\n"
        "  /status — Town overview\n"
        "  /mail — Show inbox\n"
        "  /read `<id>` — Read a message\n"
        "  /rigs — List rigs\n"
        "  /polecats — List polecats\n"
        "  /ready — Issues ready to work\n"
        "  /hook — Check what's hooked\n"
        "  /convoys — Convoy dashboard\n"
        "  /version — Gas Town version\n\n"
        "*Actions (with confirmation):*\n"
        "  /sling `<bead> <rig>` — Spawn polecat\n"
        "  /nudge `<target> <msg>` — Nudge agent\n"
        "  /send `<addr>` `<msg>` — Send mail\n"
        "  /markread `<id>` — Mark mail read\n"
    )
    await update.message.reply_text(text, parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("⏳ Fetching status…")
    raw = gt("status", "--json")
    await msg.edit_text(fmt_status(raw), parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_mail(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("⏳ Checking mail…")
    raw = gt("mail", "inbox", "--json")
    await msg.edit_text(fmt_mail(raw), parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_read(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not context.args:
        await update.message.reply_text("Usage: /read <mail-id>")
        return
    mail_id = context.args[0]
    msg = await update.message.reply_text(f"⏳ Reading {mail_id}…")
    raw = gt("mail", "read", mail_id)
    await msg.edit_text(mono(raw), parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_rigs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("⏳ Listing rigs…")
    raw = gt("rig", "list")
    await msg.edit_text(mono(raw), parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_polecats(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("⏳ Listing polecats…")
    raw = gt("polecat", "list", "--all", "--json")
    await msg.edit_text(fmt_polecats(raw), parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_ready(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("⏳ Checking ready issues…")
    raw = bd("ready", "--json")
    await msg.edit_text(fmt_ready(raw), parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_hook(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("⏳ Checking hook…")
    raw = gt("hook")
    await msg.edit_text(mono(raw), parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_convoys(update: Update, context: ContextTypes.DEFAULT_TYPE):
    msg = await update.message.reply_text("⏳ Loading convoys…")
    raw = gt("convoy", "list", "--json")
    await msg.edit_text(fmt_convoys(raw), parse_mode=ParseMode.MARKDOWN)


@authorized
async def cmd_version(update: Update, context: ContextTypes.DEFAULT_TYPE):
    raw = gt("version")
    await update.message.reply_text(f"`{raw}`", parse_mode=ParseMode.MARKDOWN)


# ---------------------------------------------------------------------------
# Command handlers — actions with confirmation
# ---------------------------------------------------------------------------


PENDING_ACTIONS: dict[str, dict] = {}


def confirm_keyboard(action_id: str) -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("✅ Confirm", callback_data=f"confirm:{action_id}"),
            InlineKeyboardButton("❌ Cancel", callback_data=f"cancel:{action_id}"),
        ]
    ])


@authorized
async def cmd_sling(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if len(context.args) < 2:
        await update.message.reply_text("Usage: /sling <bead-id> <rig>")
        return
    bead_id, rig = context.args[0], context.args[1]
    action_id = f"sling-{bead_id}-{int(time.time())}"
    PENDING_ACTIONS[action_id] = {
        "type": "sling",
        "cmd": [GT_BIN, "sling", bead_id, rig],
        "desc": f"Sling `{bead_id}` to `{rig}`",
    }
    await update.message.reply_text(
        f"⚠️ Confirm: sling `{bead_id}` → `{rig}`?",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=confirm_keyboard(action_id),
    )


@authorized
async def cmd_nudge(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if len(context.args) < 2:
        await update.message.reply_text("Usage: /nudge <target> <message>")
        return
    target = context.args[0]
    message = " ".join(context.args[1:])
    action_id = f"nudge-{target}-{int(time.time())}"
    PENDING_ACTIONS[action_id] = {
        "type": "nudge",
        "cmd": [GT_BIN, "nudge", target, message],
        "desc": f"Nudge `{target}`: {message}",
    }
    await update.message.reply_text(
        f"⚠️ Confirm: nudge `{target}` with message?\n\n_{message}_",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=confirm_keyboard(action_id),
    )


@authorized
async def cmd_send(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if len(context.args) < 2:
        await update.message.reply_text("Usage: /send <address> <message>")
        return
    addr = context.args[0]
    message = " ".join(context.args[1:])
    action_id = f"send-{addr}-{int(time.time())}"
    PENDING_ACTIONS[action_id] = {
        "type": "send",
        "cmd": [GT_BIN, "mail", "send", addr, "-s", "Via Telegram", "-m", message],
        "desc": f"Send mail to `{addr}`",
    }
    await update.message.reply_text(
        f"⚠️ Confirm: send mail to `{addr}`?\n\n_{message}_",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=confirm_keyboard(action_id),
    )


@authorized
async def cmd_markread(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not context.args:
        await update.message.reply_text("Usage: /markread <mail-id>")
        return
    mail_id = context.args[0]
    action_id = f"markread-{mail_id}-{int(time.time())}"
    PENDING_ACTIONS[action_id] = {
        "type": "markread",
        "cmd": [GT_BIN, "mail", "mark-read", mail_id],
        "desc": f"Mark `{mail_id}` as read",
    }
    await update.message.reply_text(
        f"⚠️ Confirm: mark `{mail_id}` as read?",
        parse_mode=ParseMode.MARKDOWN,
        reply_markup=confirm_keyboard(action_id),
    )


async def handle_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    if query.message.chat.id not in ALLOWED_CHAT_IDS:
        await query.answer("Unauthorized.")
        return

    await query.answer()
    data = query.data
    parts = data.split(":", 1)
    if len(parts) != 2:
        return

    action, action_id = parts[0], parts[1]
    pending = PENDING_ACTIONS.pop(action_id, None)

    if action == "cancel":
        await query.edit_message_text("❌ Cancelled.")
        return

    if action == "confirm" and pending:
        await query.edit_message_text(f"⏳ Executing: {pending['desc']}…", parse_mode=ParseMode.MARKDOWN)
        raw = run_cmd(pending["cmd"], timeout=60)
        await query.edit_message_text(
            f"✅ Done: {pending['desc']}\n\n{mono(raw)}",
            parse_mode=ParseMode.MARKDOWN,
        )
    else:
        await query.edit_message_text("⚠️ Action expired or not found.")


# ---------------------------------------------------------------------------
# Notification poller — push alerts for new mail
# ---------------------------------------------------------------------------


def load_state() -> dict:
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except (json.JSONDecodeError, OSError):
            pass
    return {}


def save_state(state: dict):
    STATE_FILE.write_text(json.dumps(state))


async def check_new_mail(context: ContextTypes.DEFAULT_TYPE):
    """Periodic job: notify if new unread mail arrives."""
    raw = gt("mail", "inbox", "--json")
    data = try_parse_json(raw)
    if not data or not isinstance(data, list):
        return

    unread = [m for m in data if not m.get("read")]
    unread_ids = {m["id"] for m in unread}

    state = load_state()
    seen_ids = set(state.get("seen_unread_ids", []))
    new_ids = unread_ids - seen_ids

    if new_ids:
        new_msgs = [m for m in unread if m["id"] in new_ids]
        lines = [f"📬 *{len(new_msgs)} new message(s):*\n"]
        for m in new_msgs[:10]:
            subj = m.get("subject", "(no subject)")
            sender = m.get("from", "?")
            mid = m.get("id", "?")
            lines.append(f"  `{mid}` from `{sender}`\n    {subj}")

        text = "\n".join(lines)
        for chat_id in ALLOWED_CHAT_IDS:
            try:
                await context.bot.send_message(
                    chat_id=chat_id,
                    text=text,
                    parse_mode=ParseMode.MARKDOWN,
                )
            except Exception as exc:
                log.warning("Failed to send notification to %s: %s", chat_id, exc)

    # Update seen set — keep only currently-unread IDs to avoid unbounded growth
    state["seen_unread_ids"] = list(unread_ids)
    state["last_check"] = int(time.time())
    save_state(state)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main():
    if not BOT_TOKEN:
        print("TELEGRAM_BOT_TOKEN not set. Exiting.", file=sys.stderr)
        sys.exit(1)
    if not ALLOWED_CHAT_IDS:
        print("TELEGRAM_CHAT_ID not set. Exiting.", file=sys.stderr)
        sys.exit(1)

    app = Application.builder().token(BOT_TOKEN).build()

    # Read-only commands
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("help", cmd_help))
    app.add_handler(CommandHandler("status", cmd_status))
    app.add_handler(CommandHandler("mail", cmd_mail))
    app.add_handler(CommandHandler("read", cmd_read))
    app.add_handler(CommandHandler("rigs", cmd_rigs))
    app.add_handler(CommandHandler("polecats", cmd_polecats))
    app.add_handler(CommandHandler("ready", cmd_ready))
    app.add_handler(CommandHandler("hook", cmd_hook))
    app.add_handler(CommandHandler("convoys", cmd_convoys))
    app.add_handler(CommandHandler("version", cmd_version))

    # Action commands (with confirmation)
    app.add_handler(CommandHandler("sling", cmd_sling))
    app.add_handler(CommandHandler("nudge", cmd_nudge))
    app.add_handler(CommandHandler("send", cmd_send))
    app.add_handler(CommandHandler("markread", cmd_markread))

    # Confirmation callback
    app.add_handler(CallbackQueryHandler(handle_callback))

    # Periodic mail check
    if POLL_INTERVAL > 0:
        app.job_queue.run_repeating(
            check_new_mail,
            interval=POLL_INTERVAL,
            first=10,
            name="mail_poller",
        )
        log.info("Mail polling enabled every %ds", POLL_INTERVAL)

    log.info("Gas Town bot starting (allowed chats: %s)", ALLOWED_CHAT_IDS)
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
