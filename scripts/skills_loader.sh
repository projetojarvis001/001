CLAUDE_SKILLS="/Users/jarvis001/jarvis/.claude/skills"
if [ -d "$CLAUDE_SKILLS" ]; then
  echo "[$(date)] Claude agent skills disponíveis: $(ls $CLAUDE_SKILLS | wc -l)" >> /tmp/skills.log
fi
