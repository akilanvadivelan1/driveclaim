# Running MiroFish on Loopd

MiroFish is a separate project: https://github.com/666ghj/MiroFish (AGPL-3.0). It runs many AI agents that role-play a scenario and then writes a report. The answers are a language model's role play, not real market data, so treat them as a way to find questions and risks, not as a forecast.

## You need

- Node 18 or newer, Python 3.11 or 3.12, and `uv` (or Docker instead).
- An API key for an OpenAI-compatible language model service. This is paid, and a simulation makes many calls. Set a spending limit with the provider first, and start with fewer than 40 rounds.
- A free Zep Cloud key from https://app.getzep.com for agent memory.
- Free disk space. The Python packages are large.

Do not paste keys into chat, and do not commit the `.env` file.

## Steps

    cd ~ && git clone https://github.com/666ghj/MiroFish.git && cd MiroFish
    cp .env.example .env
    open -e .env
    npm run setup:all
    npm run dev

Put your keys in `.env` (`LLM_API_KEY`, `ZEP_API_KEY`, and the service address and model name that match your provider), save it, then open http://localhost:3000.

## Using it

1. Upload `seed-loopd.md` from this folder as the seed material.
2. Paste the text from `prediction-request.md` as the prediction requirement.
3. Run a short simulation first.
4. Read the report, then chat with individual agents to ask why they quit or complained.

Come back and tell me what it found, and I will turn the useful findings into changes to the game.
