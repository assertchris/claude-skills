#!/bin/sh
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "?"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

GREEN=$(printf '\033[32m')
YELLOW=$(printf '\033[33m')
RED=$(printf '\033[31m')
RESET=$(printf '\033[0m')

# --- Usage limits (session 5h / weekly 7d) ---
usage_text=""
CACHE_FILE="/tmp/claude-statusline-usage.json"
CACHE_MAX_AGE=60

fetch_usage() {
    # Platform-aware token reading
    token=""
    if [ "$(uname)" = "Darwin" ]; then
        creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$creds" ]; then
            token=$(printf '%s' "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        fi
    else
        # Linux: try secret-tool first, then fallback to credentials file
        creds=$(secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        if [ -n "$creds" ]; then
            token=$(printf '%s' "$creds" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
        fi
        if [ -z "$token" ] && [ -f "$HOME/.claude/.credentials.json" ]; then
            token=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
        fi
    fi

    if [ -z "$token" ]; then
        return 1
    fi

    response=$(curl -s --max-time 3 \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
        printf '%s' "$response" > "$CACHE_FILE"
        return 0
    fi
    return 1
}

# Check cache freshness
need_refresh=1
if [ -f "$CACHE_FILE" ]; then
    if [ "$(uname)" = "Darwin" ]; then
        file_mtime=$(stat -f%m "$CACHE_FILE" 2>/dev/null || echo 0)
    else
        file_mtime=$(stat -c%Y "$CACHE_FILE" 2>/dev/null || echo 0)
    fi
    now=$(date +%s)
    age=$((now - file_mtime))
    if [ "$age" -lt "$CACHE_MAX_AGE" ]; then
        need_refresh=0
    fi
fi

if [ "$need_refresh" -eq 1 ]; then
    fetch_usage
fi

# Read from cache (whether freshly written or still valid)
if [ -f "$CACHE_FILE" ]; then
    session_pct=$(jq -r '.five_hour.utilization // empty' "$CACHE_FILE" 2>/dev/null)
    week_pct=$(jq -r '.seven_day.utilization // empty' "$CACHE_FILE" 2>/dev/null)
    if [ -n "$session_pct" ] && [ -n "$week_pct" ]; then
        # Round to integer (API returns percentage values like 57.0)
        session_display=$(echo "$session_pct" | awk '{printf "%d", $1 + 0.5}')
        week_display=$(echo "$week_pct" | awk '{printf "%d", $1 + 0.5}')

        # Color based on percentage
        if [ "$session_display" -ge 90 ] 2>/dev/null; then
            sc="$RED"
        elif [ "$session_display" -ge 50 ] 2>/dev/null; then
            sc="$YELLOW"
        else
            sc="$GREEN"
        fi
        if [ "$week_display" -ge 90 ] 2>/dev/null; then
            wc="$RED"
        elif [ "$week_display" -ge 50 ] 2>/dev/null; then
            wc="$YELLOW"
        else
            wc="$GREEN"
        fi

        usage_text="  |  session ${sc}${session_display}%${RESET} / week ${wc}${week_display}%${RESET}"
    fi
fi

# --- Context bar ---
if [ -n "$used" ]; then
    bar_width=20
    filled=$(echo "$used $bar_width" | awk '{printf "%d", ($1 / 100) * $2 + 0.5}')
    empty=$((bar_width - filled))
    bar=""
    i=0
    while [ "$i" -lt "$filled" ]; do
        pct=$(( (i + 1) * 5 ))
        if [ "$pct" -le 40 ]; then
            bar="${bar}${GREEN}█"
        elif [ "$pct" -le 75 ]; then
            bar="${bar}${YELLOW}█"
        else
            bar="${bar}${RED}█"
        fi
        i=$((i + 1))
    done
    i=0
    while [ "$i" -lt "$empty" ]; do
        bar="${bar}${RESET}░"
        i=$((i + 1))
    done
    bar="${bar}${RESET}"
    printf "\n%s  |  context [%s] %d%%%s\n​\n" "$model" "$bar" "$used" "$usage_text"
else
    printf "\n%s  |  context [--]%s\n​\n" "$model" "$usage_text"
fi
