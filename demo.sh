#!/bin/bash

# ─────────────────────────────────────────────
# TurfScout Demo Pipeline
# Qualifier → Estimator → Content Creator
# ─────────────────────────────────────────────

ADDRESS="${1:-456 Desert Sun Dr, Scottsdale, AZ 85251}"
IMAGE="${2:-/Users/mudiam/turf-mailer-openclaw/9163_before.png}"

run_agent() {
  local agent="$1"
  local message="$2"
  local outfile="$3"
  openclaw agent --agent "$agent" -m "$message" --json 2>/dev/null \
    | python3 -c "
import sys, json
d = json.load(sys.stdin)
text = d['result']['payloads'][0]['text']
decoder = json.JSONDecoder()
for i, ch in enumerate(text):
    if ch in ('{', '['):
        try:
            obj, _ = decoder.raw_decode(text, i)
            print(json.dumps(obj, ensure_ascii=False))
            sys.exit(0)
        except json.JSONDecodeError:
            continue
print(text.strip())
" > "$outfile"
}

extract_json_field() {
  local text="$1"
  local field="$2"
  echo "$text" | python3 -c "
import sys, json
raw = sys.stdin.read().strip()
try:
    d = json.loads(raw)
    print(d.get('$field', ''))
except Exception as e:
    print('PARSE_ERROR: ' + str(e), file=sys.stderr)
    print('')
" 2>&1
}

echo ""
echo "🌵 TurfScout Pipeline Demo"
echo "📍 Address: $ADDRESS"
echo "────────────────────────────────────────"

# ── Step 1: Qualifier ──────────────────────
echo ""
echo "🔍 Step 1/3 — Qualifier Agent"
echo "   Analyzing property..."

QUALIFIER_INPUT="Analyze this property at $ADDRESS. Satellite view shows: large front yard with approximately 75% dead brown grass, bare dirt patches near the driveway, no xeriscape or artificial turf visible. Single-story residential home with 2-car garage."

run_agent qualifier "$QUALIFIER_INPUT" /tmp/ts_qualifier.json
cat /tmp/ts_qualifier.json

QUALIFICATION=$(python3 -c "
import sys, json
d = json.load(open('/tmp/ts_qualifier.json'))
print(d.get('classification') or d.get('qualification',''))
")

if [ "$QUALIFICATION" != "GOOD_LEAD" ]; then
  echo ""
  echo "❌ Result: BAD_LEAD — pipeline stops here."
  exit 0
fi

echo "   ✅ GOOD_LEAD — continuing pipeline..."

# ── Step 2: Estimator ─────────────────────
echo ""
echo "📐 Step 2/3 — Estimator Agent"
echo "   Calculating dimensions and pricing..."

ESTIMATOR_INPUT="Property: $ADDRESS. Qualifier result: $(cat /tmp/ts_qualifier.json). Satellite view shows: front yard roughly 35ft wide x 25ft deep. Standard single-story home with 2-car garage (~22ft wide). One concrete walkway ~4ft wide cutting through the yard. No garden beds visible."

run_agent estimator "$ESTIMATOR_INPUT" /tmp/ts_estimator.json
cat /tmp/ts_estimator.json

# ── Step 3: Content Creator ───────────────
echo ""
echo "✉️  Step 3/3 — Content Creator Agent"
echo "   Generating postcard HTML..."

CONTENT_INPUT="Create a postcard mailer for this property. Address: $ADDRESS. Qualifier data: $(cat /tmp/ts_qualifier.json). Estimator data: $(cat /tmp/ts_estimator.json). original_image: $IMAGE. IMPORTANT: respond with ONLY the raw JSON object — no markdown, no explanation, no code fences. The JSON must have an 'html' key containing the full postcard HTML."

run_agent content-creator "$CONTENT_INPUT" /tmp/ts_content.json

python3 -c "
import sys, json
d = json.load(open('/tmp/ts_content.json'))
html = d.get('html','')
if not html:
    print('   ⚠️  No html field in response')
    sys.exit(1)
with open('/tmp/turfscout_card.html','w') as f:
    f.write(html)
print(json.dumps({k:v for k,v in d.items() if k != 'html'}, indent=2))
print('   💾 Card HTML saved to /tmp/turfscout_card.html')
"

echo ""
echo "────────────────────────────────────────"
echo "✅ Pipeline complete!"
echo "   Open the card: open /tmp/turfscout_card.html"
echo ""
