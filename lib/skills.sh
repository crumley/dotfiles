# shellcheck shell=bash
#
# Agent skills: install every entry in ~/.agents/skills.list. Sourced by
# install.sh, never executed. Needs lib/common.sh.
#
# A skill comes from one of two places:
#
#   * A Ward checkout. Where a Ward workspace on this machine holds the skill's
#     repository (<workspace>/repos/<repo>), ~/.agents/skills/<name> is a
#     symlink into that checkout. Ward keeps repos/ on the main line, so the
#     skill follows main with every `ward repo refresh` and never needs a
#     `skills update`. This is the development machine's case.
#   * npx. Anywhere else, `npx skills add` installs a copy, as it always has.
#
# Linking is offline and cheap, so it runs on every install, including the
# post-merge hook's --stow-only run: a line added to skills.list is live once
# it merges. Copies need the network and are left to the full install.

# The directories holding Ward checkouts, one per line: <workspace>/repos for
# every workspace `ward` knows. DOTFILES_SKILL_CHECKOUTS, a colon-separated
# list, replaces the discovery (set it empty to never link) -- the tests use
# it, and so can a machine whose checkouts live somewhere else.
dotfiles_skill_checkout_roots() {
  if [ -n "${DOTFILES_SKILL_CHECKOUTS+x}" ]; then
    printf '%s\n' "$DOTFILES_SKILL_CHECKOUTS" | tr ':' '\n' | sed '/^$/d'
    return 0
  fi
  have ward || return 0
  local _label path
  env -u WARD_AGENT ward shell candidates workspaces 2>/dev/null |
    while IFS="$(printf '\t')" read -r _label path; do
      [ -d "$path/repos" ] && printf '%s/repos\n' "$path"
    done
  return 0
}

# owner/repo, lowercased, from anything `skills add` or `git remote` spells
# it as: crumley/markup, https://github.com/crumley/markup(.git),
# git@github.com:crumley/markup.git.
dotfiles_skill_slug() {
  printf '%s\n' "$1" |
    sed -e 's#^[a-z+]*://[^/]*/##' -e 's#^[^@/]*@[^:]*:##' -e 's#\.git$##' -e 's#/$##' |
    awk -F/ 'NF >= 2 { print $(NF-1) "/" $NF }' | tr '[:upper:]' '[:lower:]'
}

# The skill directory for <source> <name> inside a Ward checkout, or nothing.
# The checkout is <root>/<repo> and must be a clone of <source> -- the origin
# remote is compared, so a same-named repository from elsewhere never gets
# linked. The skill is looked for where the skills CLI looks first.
dotfiles_skill_checkout_dir() {
  local src=$1 name=$2 slug repo root co origin sub
  slug=$(dotfiles_skill_slug "$src")
  [ -n "$slug" ] || return 0
  # As spelled in the source, not lowercased: Ward names the checkout after it.
  repo=${src%/}
  repo=${repo##*/}
  repo=${repo%.git}
  while IFS= read -r root; do
    co="$root/$repo"
    [ -d "$co" ] || continue
    origin=$(git -C "$co" remote get-url origin 2>/dev/null) || continue
    [ "$(dotfiles_skill_slug "$origin")" = "$slug" ] || continue
    for sub in ".agents/skills/$name" "skills/$name" ".claude/skills/$name"; do
      if [ -f "$co/$sub/SKILL.md" ]; then
        (cd -- "$co/$sub" && pwd -P)
        return 0
      fi
    done
  done <<EOF
$(dotfiles_skill_checkout_roots)
EOF
  return 0
}

# Drop <name> from ~/.agents/.skill-lock.json. A skill that becomes a link
# must leave the lock, or `npx skills update -g` would write a fresh copy
# through the link into the Ward checkout. Needs node (which npx needs too).
dotfiles_skill_unlock() {
  local lock="$1/.agents/.skill-lock.json" name=$2
  [ -f "$lock" ] || return 0
  grep -q "\"$name\"" "$lock" || return 0
  if ! have node; then
    warn "skill $name: could not drop it from $lock (node missing); remove it there by hand"
    return 0
  fi
  node -e '
    const fs = require("fs"), [file, name] = process.argv.slice(1);
    const lock = JSON.parse(fs.readFileSync(file, "utf8"));
    if (lock.skills && name in lock.skills) {
      delete lock.skills[name];
      fs.writeFileSync(file, JSON.stringify(lock, null, 2) + "\n");
    }
  ' "$lock" "$name" || warn "skill $name: could not drop it from $lock"
}

# Link ~/.agents/skills/<name> to <dir>, and ~/.claude/skills/<name> to that,
# the way the skills CLI links a global install. A copy already there (from
# npx) is moved into the backup directory, never deleted.
dotfiles_skill_link() {
  local target=$1 name=$2 dir=$3
  local live="$target/.agents/skills/$name"
  local claude="$target/.claude/skills/$name"
  local rel="../../.agents/skills/$name"
  local backup

  if [ -L "$live" ] && [ "$(readlink "$live")" = "$dir" ]; then
    :
  else
    if [ -e "$live" ] && [ ! -L "$live" ]; then
      backup="${DOTFILES_BACKUP_ROOT:-$target/.dotfiles-backup}/$(date +%Y%m%dT%H%M%S)/.agents/skills"
      mkdir -p -- "$backup"
      mv -- "$live" "$backup/$name"
      info "skill $name: moved the npx copy to $backup/$name"
    fi
    mkdir -p -- "$target/.agents/skills"
    ln -sfn -- "$dir" "$live"
    info "skill $name: linked to $dir"
  fi
  dotfiles_skill_unlock "$target" "$name"

  if [ -L "$claude" ] && [ "$(readlink "$claude")" = "$rel" ]; then
    return 0
  fi
  if [ -e "$claude" ] || [ -L "$claude" ]; then
    warn "skill $name: leaving ~/.claude/skills/$name alone (it is not a link to ~/.agents/skills/$name)"
    return 0
  fi
  mkdir -p -- "$target/.claude/skills"
  ln -s -- "$rel" "$claude"
}

# Walk skills.list under <target>. <copies> is 1 to `npx skills add` what no
# Ward checkout holds, 0 to only link.
dotfiles_sync_skills() {
  local target=$1 copies=$2
  local list="$target/.agents/skills.list" src name _rest dir live
  [ -f "$list" ] || return 0
  # Never write into the repository: with ~/.agents or ~/.claude folded into a
  # symlink to the checkout, every skill would land in it.
  for live in "$target/.agents" "$target/.claude"; do
    [ -L "$live" ] || continue
    warn "agent skills: skipped ($live is a symlink; expected a real directory)"
    return 0
  done

  while read -r src name _rest; do
    case "$src" in '' | \#*) continue ;; esac
    [ -n "$name" ] || { warn "skills.list: no name for '$src', skipping"; continue; }
    dir=$(dotfiles_skill_checkout_dir "$src" "$name")
    if [ -n "$dir" ]; then
      dotfiles_skill_link "$target" "$name" "$dir"
      continue
    fi
    [ "$copies" = 1 ] || continue
    if ! have npx; then
      info "skill $name: skipped (npx missing)"
      continue
    fi
    live="$target/.agents/skills/$name"
    # A link left from a checkout that has gone: npx would write through it.
    if [ -L "$live" ]; then
      rm -f -- "$live"
    fi
    # </dev/null: npx must not eat the loop's stdin, or it swallows the
    # remaining lines and silently skips every skill after the first.
    npx -y skills add "$src" -s "$name" -g -y </dev/null || warn "skill $name failed to install"
  done <"$list"
}
