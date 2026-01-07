#!/bin/bash
# Clear way markers for fresh session
# Called on SessionStart and after compaction
#
# Clears all way markers so guidance can trigger again in the new/resumed session

rm -f /tmp/.claude-way-* 2>/dev/null
