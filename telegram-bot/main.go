package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
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

	return Config{
		BotToken:     os.Getenv("TELEGRAM_BOT_TOKEN"),
		ChatIDs:      chatIDs,
		TownRoot:     envOr("GT_TOWN_ROOT", "/home/gastown/antik"),
		GtBin:        envOr("GT_BIN", "gt"),
		BdBin:        envOr("BD_BIN", "bd"),
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
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, args[0], args[1:]...)
	cmd.Dir = cfg.TownRoot
	cmd.Env = append(os.Environ(), "NO_COLOR=1")

	out, err := cmd.CombinedOutput()
	result := strings.TrimSpace(string(out))
	if ctx.Err() == context.DeadlineExceeded {
		return "Error: command timed out"
	}
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
			pcCount := num(r, "polecat_count")
			crewCount := num(r, "crew_count")
			b.WriteString(fmt.Sprintf("  🔧 `%s` — %.0f polecats, %.0f crew\n", str(r, "name"), pcCount, crewCount))

			// Show crew and rig agents
			if agents, ok := r["agents"].([]interface{}); ok {
				for _, aRaw := range agents {
					a, ok := aRaw.(map[string]interface{})
					if !ok {
						continue
					}
					role := str(a, "role")
					icon := "⚫"
					if boolean(a, "running") {
						icon = "🟢"
					}
					unread := ""
					if n := num(a, "unread_mail"); n > 0 {
						unread = fmt.Sprintf(" 📬%.0f", n)
					}
					work := ""
					if boolean(a, "has_work") {
						work = " 🔨"
					}
					if role == "crew" {
						b.WriteString(fmt.Sprintf("    %s 👷 `%s`%s%s\n", icon, str(a, "name"), work, unread))
					}
				}
			}
		}
	}

	return b.String()
}

func fmtMail(raw string) string {
	data, ok := tryParseJSON(raw).([]interface{})
	if !ok {
		return mono(raw)
	}
	if len(data) == 0 {
		return "📭 Inbox empty."
	}

	var b strings.Builder
	b.WriteString(fmt.Sprintf("📬 *Inbox* (%d messages)\n\n", len(data)))
	limit := 15
	if len(data) < limit {
		limit = len(data)
	}
	for _, raw := range data[:limit] {
		m, ok := raw.(map[string]interface{})
		if !ok {
			continue
		}
		icon := "  "
		if !boolean(m, "read") {
			icon = "🔴"
		}
		b.WriteString(fmt.Sprintf("%s `%s` from `%s`\n    %s\n", icon, str(m, "id"), str(m, "from"), str(m, "subject")))
	}
	if len(data) > 15 {
		b.WriteString(fmt.Sprintf("\n… and %d more", len(data)-15))
	}
	return b.String()
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
	parsed, ok := tryParseJSON(raw).([]interface{})
	if !ok {
		return
	}

	unreadIDs := make(map[string]bool)
	var unread []map[string]interface{}
	for _, item := range parsed {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
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
		go func() {
			pollMail(bot, cfg)
			ticker := time.NewTicker(time.Duration(cfg.PollInterval) * time.Second)
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
		if update.Message == nil {
			continue
		}

		if !cfg.ChatIDs[update.Message.Chat.ID] {
			reply := tgbotapi.NewMessage(update.Message.Chat.ID, "Unauthorized.")
			bot.Send(reply)
			continue
		}

		handleMessage(bot, cfg, update.Message)
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

func handleMessage(bot *tgbotapi.BotAPI, cfg Config, msg *tgbotapi.Message) {
	chatID := msg.Chat.ID

	// If it's a command, handle the few we keep
	if msg.IsCommand() {
		switch msg.Command() {
		case "start":
			sendMsg(bot, chatID, fmt.Sprintf(
				"🏭 Gas Town Bot ready.\n\nYour chat ID: `%d`\n\nUse /help to see commands.", chatID))

		case "help":
			sendMsg(bot, chatID, "*Gas Town Bot*\n\n"+
				"*Commands:*\n"+
				"  /status — Town overview\n"+
				"  /version — Gas Town version\n"+
				"  /nudge — Wake the mayor\n"+
				"  /crew `<name> <msg>` — Talk to a crew member\n"+
				"  /help — This message\n\n"+
				"*Talk to mayor:*\n"+
				"Just type a message — it sends to the mayor and nudges.\n\n"+
				"_Examples:_\n"+
				"  `Merge all abp feature branches`\n"+
				"  /crew bender merge all open PRs")

		case "status":
			mid := sendLoading(bot, chatID, "⏳ Fetching status…")
			raw := gt(cfg, "status", "--json")
			sendEdit(bot, chatID, mid, fmtStatus(raw))

		case "version":
			raw := gt(cfg, "version")
			sendMsg(bot, chatID, fmt.Sprintf("`%s`", raw))

		case "mayor":
			text := msg.CommandArguments()
			if text == "" {
				sendMsg(bot, chatID, "Usage: /mayor <message>\n\nOr just type without a command.")
				return
			}
			mailMayor(bot, cfg, chatID, text)

		case "nudge":
			mid := sendLoading(bot, chatID, "🔔 Nudging mayor…")
			raw := gt(cfg, "nudge", "mayor", "Check your inbox — new instructions from Telegram")
			sendEdit(bot, chatID, mid, fmt.Sprintf("🔔 Mayor nudged.\n\n%s", mono(raw)))

		case "crew":
			args := strings.Fields(msg.CommandArguments())
			if len(args) < 2 {
				sendMsg(bot, chatID, "Usage: /crew `<name>` `<message>`\n\n_Example:_ /crew bender merge all open PRs")
				return
			}
			crewName := args[0]
			crewMsg := strings.Join(args[1:], " ")
			mailCrew(bot, cfg, chatID, crewName, crewMsg)

		default:
			sendMsg(bot, chatID, "Unknown command. Use /help or just type a message for the mayor.")
		}
		return
	}

	// Plain text → send to mayor
	text := strings.TrimSpace(msg.Text)
	if text == "" {
		return
	}
	mailMayor(bot, cfg, chatID, text)
}

func mailMayor(bot *tgbotapi.BotAPI, cfg Config, chatID int64, text string) {
	mid := sendLoading(bot, chatID, "📨 Sending to mayor…")
	gt(cfg, "mail", "send", "mayor/", "-s", "📱 Telegram", "-m", text)
	sendEdit(bot, chatID, mid, fmt.Sprintf("✅ Sent to mayor:\n_%s_", text))
}

func resolveCrew(cfg Config, name string) string {
	// Look up which rig has this crew member via gts status --json
	raw := gt(cfg, "status", "--json")
	data, ok := tryParseJSON(raw).(map[string]interface{})
	if !ok {
		return ""
	}
	rigs, ok := data["rigs"].([]interface{})
	if !ok {
		return ""
	}
	for _, rigRaw := range rigs {
		rig, ok := rigRaw.(map[string]interface{})
		if !ok {
			continue
		}
		crews, ok := rig["crews"].([]interface{})
		if !ok {
			continue
		}
		for _, c := range crews {
			if fmt.Sprintf("%v", c) == name {
				return fmt.Sprintf("%s/%s", str(rig, "name"), name)
			}
		}
	}
	return ""
}

func mailCrew(bot *tgbotapi.BotAPI, cfg Config, chatID int64, name string, text string) {
	mid := sendLoading(bot, chatID, fmt.Sprintf("📨 Sending to %s…", name))

	// Resolve crew name to rig/name address
	addr := resolveCrew(cfg, name)
	if addr == "" {
		sendEdit(bot, chatID, mid, fmt.Sprintf("❌ Crew member `%s` not found in any rig.", name))
		return
	}

	raw := gt(cfg, "mail", "send", addr, "-s", "📱 Telegram", "-m", text, "--type", "task")
	if strings.Contains(raw, "Error") || strings.Contains(raw, "error") {
		sendEdit(bot, chatID, mid, fmt.Sprintf("❌ Failed to send to `%s`:\n%s", addr, mono(raw)))
		return
	}
	gt(cfg, "nudge", addr, "Check your inbox — new instructions from Telegram")
	sendEdit(bot, chatID, mid, fmt.Sprintf("✅ Sent to `%s`:\n_%s_", addr, text))
}
