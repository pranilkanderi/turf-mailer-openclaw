# TurfScout — Knowledge Share

**Project:** TurfScout by Sonoran Labs
**Repo:** https://github.com/pranilkanderi/turf-mailer-openclaw
**Stack:** OpenClaw AI agent framework · Google Gemini 1.5 Pro · Telegram Bot · SimplyNoted API · Docker

---

## What Is This?

TurfScout is an automated AI pipeline that:

1. Looks at a satellite image of a residential property
2. Decides if the homeowner is a good candidate for artificial turf
3. Estimates the yard size and calculates an install quote
4. Generates a personalized marketing postcard
5. Physically mails that postcard to the homeowner via [SimplyNoted](https://simplynoted.com)

The entire pipeline runs through a Telegram bot — you drop in an image and an address, and a physical card goes in the mail. No manual steps.

---

## How It Works — The Pipeline

```
[Satellite Image + Address]
         |
         v
   QUALIFIER AGENT
   (GOOD_LEAD / BAD_LEAD?)
         |
    GOOD_LEAD only
         |
         v
   ESTIMATOR AGENT
   (yard sqft + cost)
         |
         v
 CONTENT CREATOR AGENT
   (6x9 HTML postcard)
         |
         v
    MAILER AGENT
  (SimplyNoted API → physical mail)
```

---

## The Framework — OpenClaw

[OpenClaw](https://openclaw.ai) is an AI agent orchestration framework. It works like this:

- **Agents are markdown files** in the `workspace/` directory. Each `.md` file is the system prompt for that agent.
- **`openclaw.json`** at the project root is the config file — it defines the AI model, Telegram channel, env vars, and gateway port.
- **The bot runs in Docker** — one `docker compose up` starts everything.
- Agents communicate by passing JSON to each other. The Project Manager (built-in orchestrator) routes tasks between agents.

---

## File Structure

```
turf-mailer-openclaw/
├── openclaw.json            # Config (gitignored — contains live credentials)
├── openclaw.json.example    # Template for new teammates (safe to commit)
├── docker-compose.yml       # Main Docker setup (port 18789)
├── docker/openclaw/
│   ├── Dockerfile           # Custom OpenClaw image build
│   └── docker-compose.yml   # Alternative compose for built image
├── workspace/
│   ├── AGENTS.md            # High-level description of all 5 agents
│   ├── SOUL.md              # Shared personality/tone for all agents
│   ├── MEMORY.md            # Shared memory (project start date, user, location)
│   ├── QUALIFIER.md         # Agent 1 — lead qualification
│   ├── ESTIMATOR.md         # Agent 2 — yard measurement + cost calculation
│   ├── CONTENT_CREATOR.md   # Agent 3 — HTML postcard generation
│   └── MAILER.md            # Agent 4 — SimplyNoted API integration
└── KNOWLEDGE_SHARE.md       # This file
```

---

## Agent Breakdown

### Agent 1 — Qualifier (`workspace/QUALIFIER.md`)

**Input:** Satellite image of a residential property

**What it does:** Uses Google Gemini's vision capability to analyze the lawn condition and classify the lead.

**Good Lead criteria:**
- Burnt, yellow, brown, or dead grass
- Bare dirt where grass should be
- Patchy lawn with >40% dead coverage

**Bad Lead (skip):**
- Healthy green grass
- Intentional xeriscape / desert landscaping
- Artificial turf already installed
- Commercial property or vacant lot

**Output JSON:**
```json
{
  "qualification": "GOOD_LEAD",
  "reason": "Large front yard with approximately 80% dead brown grass",
  "grass_condition": "dead",
  "dead_grass_percentage": 80,
  "confidence": "high",
  "yard_location": "front"
}
```

---

### Agent 2 — Estimator (`workspace/ESTIMATOR.md`)

**Input:** Same satellite image + Qualifier JSON

**What it does:** Estimates yard dimensions by using known visual anchors (garage doors, cars, sidewalks) as scale references, then applies the hardcoded pricing table.

**Pricing table (hardcoded for MVP):**

| Item | Unit | Cost |
|---|---|---|
| Artificial turf (standard) | per sqft | $1.73 |
| Artificial turf (premium) | per sqft | $3.17 |
| Base prep / removal | per sqft | $1.30 |
| Infill material | per sqft | $0.35 |
| Labor | per sqft | $1.75 |
| **Total standard install** | per sqft | **$5.13** |
| **Total premium install** | per sqft | **$6.57** |
| Minimum job charge | flat | $3,500 |

**Visual scale anchors used:**
- 2-car garage door ≈ 16 ft wide
- Single car in driveway ≈ 6 ft wide × 15 ft long
- Residential street lane ≈ 10–12 ft wide
- Front door ≈ 3 ft wide
- Sidewalk ≈ 4 ft wide

**Output JSON:** Dimensions + full pricing breakdown (standard and premium) ready for Agent 3.

---

### Agent 3 — Content Creator (`workspace/CONTENT_CREATOR.md`)

**Input:** Address + Qualifier JSON + Estimator JSON + optional before/after image URLs

**What it does:** Generates a **6×9 inch HTML postcard** personalized to the specific property. The headline is dynamically chosen based on the lawn condition.

**Headline logic:**
- `dead` / `bare_dirt` → "Tired of your dead lawn?"
- `dying` / `brown` / `yellow` → "Your lawn is giving up. You don't have to."
- `patchy` → "Your neighbors already switched."

**Card includes:**
- Dynamic headline
- Before / after images side by side
- Custom quote showing their exact sqft and price
- Call to action with phone and QR code placeholder
- Benefits list (no water bills, always green, pet-friendly, 15–20 yr lifespan)
- TurfScout by Sonoran Labs branding

**Design:** Desert/Arizona aesthetic — burnt orange (`#C8602A`), turf green (`#2E5B2E`), warm sand background (`#FDF6EE`). All styles are inline so it renders correctly when printed.

**Output JSON:**
```json
{
  "html": "<full self-contained HTML postcard>",
  "headline": "Tired of your dead lawn?",
  "sqft": 850,
  "standard_price": 4360.50,
  "premium_price": 5584.50
}
```

---

### Agent 4 — Mailer (`workspace/MAILER.md`)

**Input:** Card image URL + message body + homeowner mailing address

**What it does:** Calls the [SimplyNoted API v2](https://documenter.getpostman.com/view/3418100/2sAYHxoQAD) to physically mail the postcard to the homeowner. Two API calls:

1. `POST /cards` — registers the card design with the front image
2. `POST /single_card_mailings` — submits the mailing order with the recipient address

**Required credentials (in `openclaw.json`, never committed):**
- `SIMPLYNOTED_API_KEY`
- `SIMPLYNOTED_USER_ID`
- `SIMPLYNOTED_SENDER_PROFILE_ID`

**SimplyNoted API base URL:** `https://live.simplynoted.com/api/v2`

**Success response to Project Manager:**
```
✅ Mailer Agent: Card mailed successfully!
- Recipient: Jane Smith, Scottsdale, AZ
- Mailing ID: 6f809720-af8e-4e1c-ae19-410deea02676
- Status: Submitted to SimplyNoted for physical delivery
```

---

## Configuration — `openclaw.json`

This file is **gitignored** to protect credentials. Copy `openclaw.json.example` to get started:

```bash
cp openclaw.json.example openclaw.json
```

Then fill in:

```json
{
  "env": {
    "vars": {
      "GOOGLE_API_KEY": "",              // Google AI Studio key for Gemini
      "TELEGRAM_BOT_TOKEN": "",          // From @BotFather on Telegram
      "SIMPLYNOTED_API_KEY": "",         // From SimplyNoted dashboard
      "SIMPLYNOTED_USER_ID": "",         // From SimplyNoted dashboard
      "SIMPLYNOTED_SENDER_PROFILE_ID": "" // Create one via POST /sender_profiles
    }
  }
}
```

---

## Running Locally

```bash
# 1. Clone the repo
git clone https://github.com/pranilkanderi/turf-mailer-openclaw.git
cd turf-mailer-openclaw

# 2. Set up config
cp openclaw.json.example openclaw.json
# Fill in credentials in openclaw.json

# 3. Start the bot
docker compose up

# 4. Find your bot on Telegram
curl https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getMe
# Look for "username" in the response

# 5. Open Telegram, search for the bot, tap Start
```

---

## Demo Flow

Once the bot is running:

1. **Send the homeowner's address** as a text message:
   ```
   123 W Desert View Dr, Scottsdale, AZ 85255
   ```

2. **Send a satellite image** — screenshot from Google Maps satellite view showing the front yard clearly

3. **Watch the pipeline run** — the bot replies with progress updates at each step

4. **Final output:** A physical postcard is mailed to that address via SimplyNoted

---

## Key Design Decisions

| Decision | Why |
|---|---|
| Agents defined as markdown files | OpenClaw's native format — the `.md` is the system prompt |
| Google Gemini 1.5 Pro as primary model | Strong vision capability needed for satellite image analysis |
| Pricing hardcoded in ESTIMATOR.md | Simpler for MVP — no external database needed |
| All HTML styles inline in postcard | SimplyNoted needs a self-contained card that renders for print |
| `openclaw.json` gitignored | Contains live API keys — replaced with `.example` template |
| `GOOD_LEAD` guard in Estimator | Prevents wasted API calls if Qualifier rejects the lead |

---

## External Services Used

| Service | Purpose | Docs |
|---|---|---|
| Google Gemini 1.5 Pro | Vision AI for image analysis | [AI Studio](https://aistudio.google.com) |
| Telegram Bot API | User interface / input channel | [@BotFather](https://t.me/botfather) |
| SimplyNoted API v2 | Physical postcard mailing | [API Docs](https://documenter.getpostman.com/view/3418100/2sAYHxoQAD) |
| OpenClaw | Agent orchestration framework | [openclaw.ai](https://openclaw.ai) |
