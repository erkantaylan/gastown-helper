package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	tgbotapi "github.com/go-telegram-bot-api/telegram-bot-api/v5"
	"github.com/joho/godotenv"
)

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

type Config struct {
	BotToken     string
	ChatIDs      map[int64]bool
	TownRoot     string
	GtBin        string
	BdBin        string
	PollInterval int
	StateFile    string
}

func loadConfig() Config {
	_ = godotenv.Load()

	chatIDs := make(map[int64]bool)
	for _, raw := range strings.Split(os.Getenv("TELEGRAM_CHAT_ID"), ",") {
		raw = strings.TrimSpace(raw)
		if id, err := strconv.ParseInt(raw, 10, 64); err == nil {
			chatIDs[id] = true
		}
	}

	pollInterval := 120
	if v := os.Getenv("POLL_INTERVAL"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			pollInterval = n
		}
	}

	stateFile := os.Getenv("STATE_FILE")
	if stateFile == "" {
		home, _ := os.UserHomeDir()
		stateFile = filepath.Join(home, ".gt-bot-state.json")
	}

	gtBin := os.Getenv("GT_BIN")
	if gtBin == "" {
		gtBin = "gt"
	}
	bdBin := os.Getenv("BD_BIN")
	if bdBin == "" {
		bdBin = "bd"
	}

	return Config{
		BotToken:     os.Getenv("TELEGRAM_BOT_TOKEN"),
		ChatIDs:      chatIDs,
		TownRoot:     envOr("GT_TOWN_ROOT", "/home/gastown/antik"),
		GtBin:        gtBin,
		BdBin:        bdBin,
		PollInterval: pollInterval,
		StateFile:    stateFile,
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// ---------------------------------------------------------------------------
// Command runner
// ---------------------------------------------------------------------------

func runCmd(cfg Config, args []string) string {
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = cfg.TownRoot
	cmd.Env = append(os.Environ(), "NO_COLOR=1")

	out, err := cmd.CombinedOutput()
	result := strings.TrimSpace(string(out))
	if err != nil && result == "" {
		return fmt.Sprintf("Error: %v", err)
	}
	if result == "" {
		return "(no output)"
	}
	return result
}

func gt(cfg Config, args ...string) string {
	return runCmd(cfg, append([]string{cfg.GtBin}, args...))
}

func bd(cfg Config, args ...string) string {
	return runCmd(cfg, append([]string{cfg.BdBin}, args...))
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func truncate(s string, limit int) string {
	if len(s) <= limit {
		return s
	}
	return s[:limit-25] + "\n\n… (truncated)"
}

func mono(s string) string {
	s = strings.ReplaceAll(s, "`", "'")
	return "```\n" + truncate(s, 4000) + "\n```"
}

func tryParseJSON(raw string) interface{} {
	// strip leading non-JSON lines (e.g. "Note: No git repository...")
	lines := strings.Split(raw, "\n")
	start := 0
	for i, l := range lines {
		l = strings.TrimSpace(l)
		if l == "[" || l == "{" || strings.HasPrefix(l, "[{") || strings.HasPrefix(l, "{\"") {
			start = i
			break
		}
	}
	cleaned := strings.Join(lines[start:], "\n")

	var result interface{}
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		return nil
	}
	return result
}

func asSlice(v interface{}) []map[string]interface{} {
	arr, ok := v.([]interface{})
	if !ok {
		return nil
	}
	var out []map[string]interface{}
	for _, item := range arr {
		if m, ok := item.(map[string]interface{}); ok {
			out = append(out, m)
		}
	}
	return out
}

func str(m map[string]interface{}, key string) string {
	if v, ok := m[key]; ok {
		return fmt.Sprintf("%v", v)
	}
	return ""
}

func num(m map[string]interface{}, key string) float64 {
	if v, ok := m[key].(float64); ok {
		return v
	}
	return 0
}

func boolean(m map[string]interface{}, key string) bool {
	if v, ok := m[key].(bool); ok {
		return v
	}
	return false
}

// ---------------------------------------------------------------------------
// Formatters
// ---------------------------------------------------------------------------

func fmtStatus(raw string) string {
	data, ok := tryParseJSON(raw).(map[string]interface{})
	if !ok {
		return mono(raw)
	}

	var b strings.Builder
	b.WriteString(fmt.Sprintf("🏭 *%s*\n", str(data, "name")))

	if overseer, ok := data["overseer"].(map[string]interface{}); ok {
		if n := num(overseer, "unread_mail"); n > 0 {
			b.WriteString(fmt.Sprintf("📬 Overseer unread: %.0f\n", n))
		}
	}

	if agents, ok := data["agents"].([]interface{}); ok && len(agents) > 0 {
		b.WriteString("\n*Agents:*\n")
		for _, raw := range agents {
			a, ok := raw.(map[string]interface{})
			if !ok {
				continue
			}
			icon := "⚫"
			if boolean(a, "running") {
				icon = "🟢"
			}
			unread := ""
			if n := num(a, "unread_mail"); n > 0 {
				unread = fmt.Sprintf(" 📬%.0f", n)
			}
			b.WriteString(fmt.Sprintf("  %s `%s` — %s%s\n", icon, str(a, "name"), str(a, "state"), unread))
		}
	}

	if rigs, ok := data["rigs"].([]interface{}); ok && len(rigs) > 0 {
		b.WriteString("\n*Rigs:*\n")
		for _, raw := range rigs {
			r, ok := raw.(map[string]interface{})
			if !ok {
				continue
			}
			b.WriteString(fmt.Sprintf("  🔧 `%s` — %.0f polecats\n", str(r, "name"), num(r, "polecat_count")))
		}
	}

	return b.String()
}

func fmtMail(raw string) string {
	items := asSlice(tryParseJSON(raw))
	if items == nil {
		return mono(raw)
	}
	if len(items) == 0 {
		return "📭 Inbox empty."
	}

	var b strings.Builder
	b.WriteString(fmt.Sprintf("📬 *Inbox* (%d messages)\n\n", len(items)))
	limit := 15
	if len(items) < limit {
		limit = len(items)
	}
	for _, m := range items[:limit] {
		icon := "  "
		if !boolean(m, "read") {
			icon = "🔴"
		}
		b.WriteString(fmt.Sprintf("%s `%s` from `%s`\n    %s\n", icon, str(m, "id"), str(m, "from"), str(m, "subject")))
	}
	if len(items) > 15 {
		b.WriteString(fmt.Sprintf("\n… and %d more", len(items)-15))
	}
	return b.String()
}

func fmtReady(raw string) string {
	items := asSlice(tryParseJSON(raw))
	if items == nil {
		return mono(raw)
	}
	if len(items) == 0 {
		return "✅ No issues ready — all clear."
	}

	var b strings.Builder
	b.WriteString(fmt.Sprintf("📋 *Ready issues* (%d)\n\n", len(items)))
	limit := 20
	if len(items) < limit {
		limit = len(items)
	}
	for _, issue := range items[:limit] {
		b.WriteString(fmt.Sprintf("  `%s` P%.0f — %s\n", str(issue, "id"), num(issue, "priority"), str(issue, "title")))
	}
	if len(items) > 20 {
		b.WriteString(fmt.Sprintf("\n… and %d more", len(items)-20))
	}
	return b.String()
}

func fmtConvoys(raw string) string {
	items := asSlice(tryParseJSON(raw))
	if items == nil {
		return mono(raw)
	}
	if len(items) == 0 {
		return "🚚 No active convoys."
	}

	var b strings.Builder
	b.WriteString(fmt.Sprintf("🚚 *Convoys* (%d)\n\n", len(items)))
	limit := 15
	if len(items) < limit {
		limit = len(items)
	}
	for _, c := range items[:limit] {
		b.WriteString(fmt.Sprintf("  `%s` [%s] %s\n", str(c, "id"), str(c, "status"), str(c, "title")))
	}
	return b.String()
}

func fmtPolecats(raw string) string {
	items := asSlice(tryParseJSON(raw))
	if items == nil {
		if strings.Contains(raw, "null") || strings.TrimSpace(raw) == "null" {
			return "🐾 No active polecats."
		}
		return mono(raw)
	}
	if len(items) == 0 {
		return "🐾 No active polecats."
	}

	var b strings.Builder
	b.WriteString(fmt.Sprintf("🐾 *Polecats* (%d)\n\n", len(items)))
	for _, p := range items {
		bead := str(p, "bead")
		beadStr := ""
		if bead != "" {
			beadStr = fmt.Sprintf(" → `%s`", bead)
		}
		b.WriteString(fmt.Sprintf("  `%s/%s` [%s]%s\n", str(p, "rig"), str(p, "name"), str(p, "status"), beadStr))
	}
	return b.String()
}

// ---------------------------------------------------------------------------
// Pending actions (confirmation flow)
// ---------------------------------------------------------------------------

type PendingAction struct {
	Cmd  []string
	Desc string
}

var (
	pendingMu      sync.Mutex
	pendingActions = make(map[string]PendingAction)
)

func storePending(id string, action PendingAction) {
	pendingMu.Lock()
	defer pendingMu.Unlock()
	pendingActions[id] = action
}

func popPending(id string) (PendingAction, bool) {
	pendingMu.Lock()
	defer pendingMu.Unlock()
	a, ok := pendingActions[id]
	if ok {
		delete(pendingActions, id)
	}
	return a, ok
}

func confirmKeyboard(actionID string) tgbotapi.InlineKeyboardMarkup {
	return tgbotapi.NewInlineKeyboardMarkup(
		tgbotapi.NewInlineKeyboardRow(
			tgbotapi.NewInlineKeyboardButtonData("✅ Confirm", "confirm:"+actionID),
			tgbotapi.NewInlineKeyboardButtonData("❌ Cancel", "cancel:"+actionID),
		),
	)
}

// ---------------------------------------------------------------------------
// Mail notification poller
// ---------------------------------------------------------------------------

type BotState struct {
	SeenUnreadIDs []string `json:"seen_unread_ids"`
	LastCheck     int64    `json:"last_check"`
}

func loadState(path string) BotState {
	data, err := os.ReadFile(path)
	if err != nil {
		return BotState{}
	}
	var s BotState
	_ = json.Unmarshal(data, &s)
	return s
}

func saveState(path string, s BotState) {
	data, _ := json.Marshal(s)
	_ = os.WriteFile(path, data, 0644)
}

func pollMail(bot *tgbotapi.BotAPI, cfg Config) {
	raw := gt(cfg, "mail", "inbox", "--json")
	items := asSlice(tryParseJSON(raw))
	if items == nil {
		return
	}

	var unread []map[string]interface{}
	unreadIDs := make(map[string]bool)
	for _, m := range items {
		if !boolean(m, "read") {
			unread = append(unread, m)
			unreadIDs[str(m, "id")] = true
		}
	}

	state := loadState(cfg.StateFile)
	seenSet := make(map[string]bool)
	for _, id := range state.SeenUnreadIDs {
		seenSet[id] = true
	}

	var newMsgs []map[string]interface{}
	for _, m := range unread {
		if !seenSet[str(m, "id")] {
			newMsgs = append(newMsgs, m)
		}
	}

	if len(newMsgs) > 0 {
		var b strings.Builder
		b.WriteString(fmt.Sprintf("📬 *%d new message(s):*\n\n", len(newMsgs)))
		limit := 10
		if len(newMsgs) < limit {
			limit = len(newMsgs)
		}
		for _, m := range newMsgs[:limit] {
			b.WriteString(fmt.Sprintf("  `%s` from `%s`\n    %s\n", str(m, "id"), str(m, "from"), str(m, "subject")))
		}

		text := b.String()
		for chatID := range cfg.ChatIDs {
			msg := tgbotapi.NewMessage(chatID, text)
			msg.ParseMode = "Markdown"
			if _, err := bot.Send(msg); err != nil {
				log.Printf("Failed to send notification to %d: %v", chatID, err)
			}
		}
	}

	// Update state
	var ids []string
	for id := range unreadIDs {
		ids = append(ids, id)
	}
	state.SeenUnreadIDs = ids
	state.LastCheck = time.Now().Unix()
	saveState(cfg.StateFile, state)
}

// ---------------------------------------------------------------------------
// Bot
// ---------------------------------------------------------------------------

func main() {
	cfg := loadConfig()

	if cfg.BotToken == "" {
		log.Fatal("TELEGRAM_BOT_TOKEN not set")
	}
	if len(cfg.ChatIDs) == 0 {
		log.Fatal("TELEGRAM_CHAT_ID not set")
	}

	bot, err := tgbotapi.NewBotAPI(cfg.BotToken)
	if err != nil {
		log.Fatalf("Failed to create bot: %v", err)
	}
	log.Printf("Authorized as @%s (allowed chats: %v)", bot.Self.UserName, cfg.ChatIDs)

	// Start mail poller
	if cfg.PollInterval > 0 {
		ticker := time.NewTicker(time.Duration(cfg.PollInterval) * time.Second)
		go func() {
			for range ticker.C {
				pollMail(bot, cfg)
			}
		}()
		log.Printf("Mail polling enabled every %ds", cfg.PollInterval)
	}

	u := tgbotapi.NewUpdate(0)
	u.Timeout = 60
	updates := bot.GetUpdatesChan(u)

	// Graceful shutdown
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigCh
		log.Println("Shutting down…")
		bot.StopReceivingUpdates()
		os.Exit(0)
	}()

	for update := range updates {
		if update.CallbackQuery != nil {
			handleCallback(bot, cfg, update.CallbackQuery)
			continue
		}

		if update.Message == nil || !update.Message.IsCommand() {
			continue
		}

		if !cfg.ChatIDs[update.Message.Chat.ID] {
			reply := tgbotapi.NewMessage(update.Message.Chat.ID, "Unauthorized.")
			bot.Send(reply)
			continue
		}

		handleCommand(bot, cfg, update.Message)
	}
}

func sendMsg(bot *tgbotapi.BotAPI, chatID int64, text string) {
	msg := tgbotapi.NewMessage(chatID, text)
	msg.ParseMode = "Markdown"
	bot.Send(msg)
}

func sendEdit(bot *tgbotapi.BotAPI, chatID int64, msgID int, text string) {
	edit := tgbotapi.NewEditMessageText(chatID, msgID, text)
	edit.ParseMode = "Markdown"
	bot.Send(edit)
}

func sendLoading(bot *tgbotapi.BotAPI, chatID int64, text string) int {
	msg := tgbotapi.NewMessage(chatID, text)
	sent, _ := bot.Send(msg)
	return sent.MessageID
}

func handleCommand(bot *tgbotapi.BotAPI, cfg Config, msg *tgbotapi.Message) {
	chatID := msg.Chat.ID
	args := strings.Fields(msg.CommandArguments())

	switch msg.Command() {

	// --- Utility ---

	case "start":
		sendMsg(bot, chatID, fmt.Sprintf(
			"🏭 Gas Town Bot ready.\n\nYour chat ID: `%d`\n\nUse /help to see available commands.", chatID))

	case "help":
		sendMsg(bot, chatID, "*Gas Town Bot Commands*\n\n"+
			"*Read-only:*\n"+
			"  /status — Town overview\n"+
			"  /mail — Show inbox\n"+
			"  /read `<id>` — Read a message\n"+
			"  /rigs — List rigs\n"+
			"  /polecats — List polecats\n"+
			"  /ready — Issues ready to work\n"+
			"  /hook — Check what's hooked\n"+
			"  /convoys — Convoy dashboard\n"+
			"  /version — Gas Town version\n\n"+
			"*Actions (with confirmation):*\n"+
			"  /sling `<bead> <rig>` — Spawn polecat\n"+
			"  /nudge `<target> <msg>` — Nudge agent\n"+
			"  /send `<addr>` `<msg>` — Send mail\n"+
			"  /markread `<id>` — Mark mail read")

	case "version":
		raw := gt(cfg, "version")
		sendMsg(bot, chatID, fmt.Sprintf("`%s`", raw))

	// --- Read-only ---

	case "status":
		mid := sendLoading(bot, chatID, "⏳ Fetching status…")
		raw := gt(cfg, "status", "--json")
		sendEdit(bot, chatID, mid, fmtStatus(raw))

	case "mail":
		mid := sendLoading(bot, chatID, "⏳ Checking mail…")
		raw := gt(cfg, "mail", "inbox", "--json")
		sendEdit(bot, chatID, mid, fmtMail(raw))

	case "read":
		if len(args) == 0 {
			sendMsg(bot, chatID, "Usage: /read <mail-id>")
			return
		}
		mid := sendLoading(bot, chatID, fmt.Sprintf("⏳ Reading %s…", args[0]))
		raw := gt(cfg, "mail", "read", args[0])
		sendEdit(bot, chatID, mid, mono(raw))

	case "rigs":
		mid := sendLoading(bot, chatID, "⏳ Listing rigs…")
		raw := gt(cfg, "rig", "list")
		sendEdit(bot, chatID, mid, mono(raw))

	case "polecats":
		mid := sendLoading(bot, chatID, "⏳ Listing polecats…")
		raw := gt(cfg, "polecat", "list", "--all", "--json")
		sendEdit(bot, chatID, mid, fmtPolecats(raw))

	case "ready":
		mid := sendLoading(bot, chatID, "⏳ Checking ready issues…")
		raw := bd(cfg, "ready", "--json")
		sendEdit(bot, chatID, mid, fmtReady(raw))

	case "hook":
		mid := sendLoading(bot, chatID, "⏳ Checking hook…")
		raw := gt(cfg, "hook")
		sendEdit(bot, chatID, mid, mono(raw))

	case "convoys":
		mid := sendLoading(bot, chatID, "⏳ Loading convoys…")
		raw := gt(cfg, "convoy", "list", "--json")
		sendEdit(bot, chatID, mid, fmtConvoys(raw))

	// --- Actions (with confirmation) ---

	case "sling":
		if len(args) < 2 {
			sendMsg(bot, chatID, "Usage: /sling <bead-id> <rig>")
			return
		}
		actionID := fmt.Sprintf("sling-%s-%d", args[0], time.Now().UnixMilli())
		storePending(actionID, PendingAction{
			Cmd:  []string{cfg.GtBin, "sling", args[0], args[1]},
			Desc: fmt.Sprintf("sling `%s` → `%s`", args[0], args[1]),
		})
		m := tgbotapi.NewMessage(chatID, fmt.Sprintf("⚠️ Confirm: sling `%s` → `%s`?", args[0], args[1]))
		m.ParseMode = "Markdown"
		kb := confirmKeyboard(actionID)
		m.ReplyMarkup = kb
		bot.Send(m)

	case "nudge":
		if len(args) < 2 {
			sendMsg(bot, chatID, "Usage: /nudge <target> <message>")
			return
		}
		target := args[0]
		message := strings.Join(args[1:], " ")
		actionID := fmt.Sprintf("nudge-%s-%d", target, time.Now().UnixMilli())
		storePending(actionID, PendingAction{
			Cmd:  []string{cfg.GtBin, "nudge", target, message},
			Desc: fmt.Sprintf("nudge `%s`", target),
		})
		m := tgbotapi.NewMessage(chatID, fmt.Sprintf("⚠️ Confirm: nudge `%s`?\n\n_%s_", target, message))
		m.ParseMode = "Markdown"
		kb := confirmKeyboard(actionID)
		m.ReplyMarkup = kb
		bot.Send(m)

	case "send":
		if len(args) < 2 {
			sendMsg(bot, chatID, "Usage: /send <address> <message>")
			return
		}
		addr := args[0]
		message := strings.Join(args[1:], " ")
		actionID := fmt.Sprintf("send-%s-%d", addr, time.Now().UnixMilli())
		storePending(actionID, PendingAction{
			Cmd:  []string{cfg.GtBin, "mail", "send", addr, "-s", "Via Telegram", "-m", message},
			Desc: fmt.Sprintf("send mail to `%s`", addr),
		})
		m := tgbotapi.NewMessage(chatID, fmt.Sprintf("⚠️ Confirm: send mail to `%s`?\n\n_%s_", addr, message))
		m.ParseMode = "Markdown"
		kb := confirmKeyboard(actionID)
		m.ReplyMarkup = kb
		bot.Send(m)

	case "markread":
		if len(args) == 0 {
			sendMsg(bot, chatID, "Usage: /markread <mail-id>")
			return
		}
		actionID := fmt.Sprintf("markread-%s-%d", args[0], time.Now().UnixMilli())
		storePending(actionID, PendingAction{
			Cmd:  []string{cfg.GtBin, "mail", "mark-read", args[0]},
			Desc: fmt.Sprintf("mark `%s` as read", args[0]),
		})
		m := tgbotapi.NewMessage(chatID, fmt.Sprintf("⚠️ Confirm: mark `%s` as read?", args[0]))
		m.ParseMode = "Markdown"
		kb := confirmKeyboard(actionID)
		m.ReplyMarkup = kb
		bot.Send(m)
	}
}

func handleCallback(bot *tgbotapi.BotAPI, cfg Config, cb *tgbotapi.CallbackQuery) {
	if !cfg.ChatIDs[cb.Message.Chat.ID] {
		callback := tgbotapi.NewCallback(cb.ID, "Unauthorized")
		bot.Request(callback)
		return
	}

	callback := tgbotapi.NewCallback(cb.ID, "")
	bot.Request(callback)

	parts := strings.SplitN(cb.Data, ":", 2)
	if len(parts) != 2 {
		return
	}
	action, actionID := parts[0], parts[1]
	chatID := cb.Message.Chat.ID
	msgID := cb.Message.MessageID

	if action == "cancel" {
		popPending(actionID)
		sendEdit(bot, chatID, msgID, "❌ Cancelled.")
		return
	}

	if action == "confirm" {
		pending, ok := popPending(actionID)
		if !ok {
			sendEdit(bot, chatID, msgID, "⚠️ Action expired or not found.")
			return
		}
		sendEdit(bot, chatID, msgID, fmt.Sprintf("⏳ Executing: %s…", pending.Desc))
		raw := runCmd(cfg, pending.Cmd)
		sendEdit(bot, chatID, msgID, fmt.Sprintf("✅ Done: %s\n\n%s", pending.Desc, mono(raw)))
	}
}
