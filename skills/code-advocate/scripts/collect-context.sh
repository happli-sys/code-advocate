#!/bin/bash
# collect-context.sh — Collect context for Code Advocate adversarial validation
# Usage: ./collect-context.sh <file_path> [function_name]
#
# Collects:
# 1. Target file content
# 2. Git blame for the file
# 3. Recent commits touching the file
# 4. Related test files
# 5. Related proto/API definition files
# 6. Project conventions (CLAUDE.md)

set -euo pipefail

FILE_PATH="${1:?Usage: collect-context.sh <file_path> [function_name]}"
FUNC_NAME="${2:-}"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "========================================="
echo "Code Advocate — Context Collection"
echo "========================================="
echo ""

# 1. Target file content
echo "--- TARGET FILE: ${FILE_PATH} ---"
if [ -f "${FILE_PATH}" ]; then
    cat -n "${FILE_PATH}"
else
    echo "[ERROR] File not found: ${FILE_PATH}"
    exit 1
fi
echo ""

# 2. Git blame
echo "--- GIT BLAME ---"
if git rev-parse --is-inside-work-tree &>/dev/null; then
    git blame -f -n "${FILE_PATH}" 2>/dev/null || echo "[WARN] git blame failed"
else
    echo "[WARN] Not a git repository"
fi
echo ""

# 3. Recent commits
echo "--- RECENT COMMITS (last 10) ---"
if git rev-parse --is-inside-work-tree &>/dev/null; then
    git log --oneline -10 -- "${FILE_PATH}" 2>/dev/null || echo "[WARN] git log failed"
else
    echo "[WARN] Not a git repository"
fi
echo ""

# 4. Related test files
echo "--- RELATED TEST FILES ---"
DIR="$(dirname "${FILE_PATH}")"
BASENAME="$(basename "${FILE_PATH}" .go)"

# Look for test files in common locations
for search_dir in "${PROJECT_ROOT}/tests" "${DIR}" "${PROJECT_ROOT}"; do
    if [ -d "${search_dir}" ]; then
        found=$(find "${search_dir}" -name "*${BASENAME}*_test.go" -o -name "*${BASENAME}*test*" 2>/dev/null | head -5)
        if [ -n "${found}" ]; then
            echo "${found}"
        fi
    fi
done
echo ""

# 5. Related proto files
echo "--- RELATED PROTO/API DEFINITIONS ---"
for search_dir in "${PROJECT_ROOT}/api" "${PROJECT_ROOT}/proto" "${PROJECT_ROOT}/idl"; do
    if [ -d "${search_dir}" ]; then
        found=$(find "${search_dir}" -name "*.proto" -o -name "*.thrift" -o -name "*.swagger.json" 2>/dev/null | head -10)
        if [ -n "${found}" ]; then
            echo "${found}"
        fi
    fi
done
echo ""

# 6. Project conventions
echo "--- PROJECT CONVENTIONS ---"
for claude_file in "${PROJECT_ROOT}/CLAUDE.md" "${PROJECT_ROOT}/.claude/CLAUDE.md" "${PROJECT_ROOT}/doc/CLAUDE.md"; do
    if [ -f "${claude_file}" ]; then
        echo "Found: ${claude_file}"
        head -50 "${claude_file}"
        echo "... (first 50 lines)"
        echo ""
    fi
done

# 7. Function-specific: find callers (if function name provided)
if [ -n "${FUNC_NAME}" ]; then
    echo "--- CALLERS OF ${FUNC_NAME} ---"
    if command -v grep &>/dev/null; then
        grep -rn "${FUNC_NAME}" "${PROJECT_ROOT}" --include="*.go" 2>/dev/null | grep -v "_test.go" | grep -v "^${FILE_PATH}" | head -20 || echo "[INFO] No callers found"
    fi
    echo ""
fi

echo "========================================="
echo "Context collection complete."
echo "========================================="
