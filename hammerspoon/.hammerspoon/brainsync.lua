-- brainsync.lua -- keep the b3 vault converged across laptops at the moments
-- this machine is left and arrived at.
--
-- The vault is edited by hand on two laptops. The failure it guards against is
-- walking away from one with edits uncommitted and opening the other without
-- them. So the syncs hang off the machine's own transitions:
--
--   leaving   screensDidLock, systemWillSleep   b3-sync-runner --settle 0
--   arriving  systemDidWake, screensDidUnlock   b3-sync-runner  (default settle)
--   on demand the hotkey, or BrainSync.run()    b3-sync-runner --settle 0
--
-- Leaving uses --settle 0 because typing has stopped: every edit is final
-- enough to commit. The hotkey does too, because the key was pressed on
-- purpose and a deferral would skip the very pull that was asked for. Arriving
-- keeps b3's default settle, which protects a file that is somehow still being
-- written. The LaunchAgent (com.crumley.b3-sync) is the timed backstop.
--
-- Every run goes through ~/bin/b3-sync-runner via `/bin/sh -lc`, exactly as
-- launchd runs it: one wrapper, one log (~/Library/Logs/b3-sync.log), one
-- lock. The runner queues a trigger that finds a sync in progress, so this
-- module does not have to.
--
-- Opt-in, per machine, in ~/.$hostname.hammerspoon.lua:
--
--   brainSync = true,
--   brainSyncHotkey = { mods = {"ctrl", "cmd", "option", "shift"}, key = "B" },
--                                  -- optional; this is the default; false = none
--
-- and it stays a no-op unless both a `b3` binary and the runner can be found.

local brainsync = {}

brainsync.logger = hs.logger.new('brainsync', 'info')
local log = brainsync.logger

-- A lid close is screensDidLock and then systemWillSleep a second later; an
-- open is systemDidWake and then screensDidUnlock once the password is typed.
-- Events of one kind this close together are one transition, synced once.
brainsync.debounceSeconds = 90

-- Wi-Fi rejoins a few seconds after wake. Arriving waits this long first, so
-- the pull is not the thing that finds the network missing.
brainsync.arriveDelaySeconds = 5

-- hyper+shift, the chord config.lua uses for its second layer; B for brain.
-- hyper+B is Watermelon, hyper+shift+B was free.
brainsync.defaultHotkey = { mods = { "ctrl", "cmd", "option", "shift" }, key = "B" }

local state = {
    runner = nil,      -- absolute path of ~/bin/b3-sync-runner
    b3 = nil,          -- where b3 was found, for the log
    watcher = nil,
    hotkey = nil,
    arriveTimer = nil,
    last = {},         -- kind -> { at = seconds, ok = nil|true|false }
    tasks = {},        -- running hs.task objects, held so they are not collected
}

local function home()
    return os.getenv("HOME") or ""
end

local function isExecutable(path)
    if not path or path == "" then
        return false
    end
    -- hs.fs.attributes follows symlinks, which matters: `bun link` makes
    -- ~/.bun/bin/b3 a symlink into the b3 checkout.
    local attrs = hs.fs.attributes(path)
    return attrs ~= nil and attrs.mode == "file"
        and type(attrs.permissions) == "string" and attrs.permissions:sub(3, 3) == "x"
end

-- The last line of a login shell's output that looks like an absolute path.
-- An interactive fish may print a greeting first; this skips it.
local function lastPath(output)
    local found = nil
    for line in (output or ""):gmatch("[^\r\n]+") do
        local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed:sub(1, 1) == "/" then
            found = trimmed
        end
    end
    return found
end

-- Where b3 is, or nil. Checked in the order it is cheapest to be right:
-- the usual per-user bins, then Homebrew (asked for its prefix, never
-- assumed), then whatever the login shell's PATH says. The last two run a
-- login shell (`hs.execute(cmd, true)`), so only when the first found nothing.
function brainsync.resolveB3()
    local h = home()
    for _, candidate in ipairs({ h .. "/bin/b3", h .. "/.local/bin/b3", h .. "/.bun/bin/b3" }) do
        if isExecutable(candidate) then
            return candidate
        end
    end

    local ok, prefix, status = pcall(hs.execute, "brew --prefix 2>/dev/null", true)
    if ok and status then
        prefix = lastPath(prefix)
        if prefix and isExecutable(prefix .. "/bin/b3") then
            return prefix .. "/bin/b3"
        end
    end

    local ok2, out, status2 = pcall(hs.execute, "command -v b3 2>/dev/null", true)
    if ok2 and status2 then
        local path = lastPath(out)
        if isExecutable(path) then
            return path
        end
    end
    return nil
end

-- One line out of the runner's stdout: its summary, or its summaries when a
-- queued trigger ran after it.
local function summaryOf(stdout, stderr)
    local lines = {}
    for line in (stdout or ""):gmatch("[^\r\n]+") do
        if line:match("%S") then
            lines[#lines + 1] = line
        end
    end
    if #lines == 0 then
        local lastErr = nil
        for line in (stderr or ""):gmatch("[^\r\n]+") do
            if line:match("%S") then
                lastErr = line
            end
        end
        return lastErr or "no output"
    end
    return table.concat(lines, " / ")
end

-- Start the runner. `settleZero` adds --settle 0; `announce` shows the result
-- in an alert (the hotkey does; transitions stay quiet, because the runner
-- itself raises a notification when b3 fails). `record` is the transition
-- record to mark ok/failed when it finishes. Never blocks: hs.task is async.
local function launch(reason, settleZero, announce, record)
    local args = { "-lc", 'exec "$HOME/bin/b3-sync-runner" "$@"', "b3-sync-runner", "--reason", reason }
    if settleZero then
        args[#args + 1] = "--settle"
        args[#args + 1] = "0"
    end

    local task
    task = hs.task.new("/bin/sh", function(exitCode, stdout, stderr)
        state.tasks[task] = nil
        local summary = summaryOf(stdout, stderr)
        if record then
            record.ok = (exitCode == 0)
        end
        if exitCode == 0 then
            log.i(string.format("%s: %s", reason, summary))
        else
            log.e(string.format("%s: exit %d: %s", reason, exitCode, summary))
        end
        if announce then
            hs.alert.show("b3 sync: " .. summary, 6)
        end
    end, args)

    if not task or not task:start() then
        log.e(reason .. ": could not start " .. tostring(state.runner))
        if record then
            record.ok = false
        end
        if announce then
            hs.alert.show("b3 sync: could not start the runner")
        end
        return false
    end
    state.tasks[task] = true
    log.i(string.format("%s: started%s", reason, settleZero and " (--settle 0)" or ""))
    return true
end

local function cancelArrive()
    if state.arriveTimer then
        state.arriveTimer:stop()
        state.arriveTimer = nil
    end
end

-- A leaving or arriving transition. Debounced per kind; a transition of the
-- other kind resets the window, so lock -> unlock -> lock inside a minute is
-- three syncs, not one. A run that failed does not debounce the next event:
-- a wake whose pull found no network is retried by the unlock that follows.
function brainsync.transition(kind)
    local now = hs.timer.secondsSinceEpoch()
    local last = state.last[kind]
    if last and (now - last.at) < brainsync.debounceSeconds and last.ok ~= false then
        log.d(kind .. ": same transition as " .. math.floor(now - last.at) .. "s ago; skipped")
        return false
    end

    local record = { at = now, ok = nil }
    state.last[kind] = record
    if kind == "leave" then
        state.last.arrive = nil
        -- An arrival still waiting out its delay is moot: the machine is
        -- leaving again, and this sync commits everything anyway.
        cancelArrive()
        launch("leave", true, false, record)
    else
        state.last.leave = nil
        cancelArrive()
        state.arriveTimer = hs.timer.doAfter(brainsync.arriveDelaySeconds, function()
            state.arriveTimer = nil
            launch("arrive", false, false, record)
        end)
    end
    return true
end

-- The on-demand sync: the hotkey, or `hs -c 'BrainSync.run()'` from Raycast or
-- a Shortcut (the `hs` CLI needs hs.ipc loaded; see the README).
function brainsync.run(reason)
    if not state.runner then
        hs.alert.show("b3 sync: not enabled on this machine")
        return "disabled"
    end
    hs.alert.show("b3 sync: running...", 2)
    return launch(reason or "hotkey", true, true, nil) and "started" or "failed"
end

local function eventHandler(event)
    local w = hs.caffeinate.watcher
    if event == w.screensDidLock or event == w.systemWillSleep then
        brainsync.transition("leave")
    elseif event == w.systemDidWake or event == w.screensDidUnlock then
        brainsync.transition("arrive")
    end
end
brainsync._eventHandler = eventHandler

-- settings: the table utils.load_host_settings returned. Returns true when
-- enabled. Everything is guarded: a machine that has not opted in, or has no
-- b3, or has not linked the b3sync package, gets a log line and nothing else.
function brainsync.start(settings)
    settings = settings or {}
    if settings.brainSync ~= true then
        log.i("disabled: set brainSync = true in the host settings file to enable")
        return false
    end

    local runner = home() .. "/bin/b3-sync-runner"
    if not isExecutable(runner) then
        log.w("disabled: " .. runner .. " not found -- link the b3sync package (./install.sh b3sync)")
        return false
    end

    local b3 = brainsync.resolveB3()
    if not b3 then
        log.w("disabled: no b3 binary found in ~/bin, ~/.local/bin, ~/.bun/bin, Homebrew, or the login shell's PATH")
        return false
    end
    state.runner = runner
    state.b3 = b3
    log.i("b3 at " .. b3 .. "; runner at " .. runner)

    state.watcher = hs.caffeinate.watcher.new(eventHandler)
    state.watcher:start()

    local hk = settings.brainSyncHotkey
    if hk == nil then
        hk = brainsync.defaultHotkey
    end
    if type(hk) == "table" and hk.key then
        state.hotkey = hs.hotkey.bind(hk.mods or {}, hk.key, function()
            brainsync.run("hotkey")
        end)
    elseif hk then
        log.w("brainSyncHotkey should be { mods = {...}, key = \"B\" } or false; no hotkey bound")
    end
    return true
end

function brainsync.stop()
    cancelArrive()
    if state.watcher then
        state.watcher:stop()
        state.watcher = nil
    end
    if state.hotkey then
        state.hotkey:delete()
        state.hotkey = nil
    end
    state.runner = nil
    state.last = {}
end

return brainsync
