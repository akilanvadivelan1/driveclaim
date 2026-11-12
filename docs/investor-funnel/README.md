# Investor funnel simulation

`simulate.py` shows what a typical fundraising funnel produces for the outreach you plan. It is a model, not a prediction. Nobody can say how many investors Loopd will get.

## Run it

    python3 simulate.py
    python3 simulate.py --warm 10 --cold 50

`--warm` is how many warm introductions you could realistically get, meaning someone the investor trusts introduces you. `--cold` is how many investors you would email with no connection.

## How the model works

Every contact has to reply, then show up to a meeting, then put money in. Each trial picks the rates at random from the ranges below, because the true rates are unknown, then simulates who passes each step. It repeats this 20,000 times and reports how often you end up with none, one or more, or three or more.

## Where the numbers come from

| Step | Range used | Source and how much to trust it |
| --- | --- | --- |
| Warm intro replies | 20 to 40 percent | A blog post on warm introductions, [funden.com](https://funden.com/blog/warm-introductions-to-vcs). Vendor content, not a study. |
| Cold email replies | 1 to 5 percent | Several outreach blogs, for example [flowlie.com](https://www.flowlie.com/blog/what-is-network-analysis-for-fundraising/). Vendor content. Figures range from 1 to 7.5 percent. |
| Meeting show rate | 85 to 95 percent warm, 50 to 60 percent cold | Same funden.com post. |
| Meeting to signed check, typical | 5 to 15 percent | [Allied Venture Partners' pipeline calculator](https://www.allied.vc/tools/investor-pipeline-calculator), for pre-seed founders who are raising. |
| Meeting to signed check, prototype | 1 to 5 percent | **My assumption.** About a third of typical, for an unlaunched app with no users and one developer. |
| Meeting to signed check, strong traction | 10 to 25 percent | **My assumption.** |

As a sanity check, DocSend reported that founders who closed a seed round had held about 40 investor meetings ([DocSend](https://www.docsend.com/blog/a-brief-anatomy-of-a-successful-seed-raise/)). That figure only covers raises that succeeded, so it flatters the odds.

## Limits

- The reply and show rates come from marketing blogs, so treat them as rough. The result is most sensitive to the meeting to check rate, and for a pre-launch app that rate is my guess.
- It ignores the idea, the team, timing, the market and how much each investor would give.
- It ignores friends and family, who invest because they know you and not because of a funnel.
- It treats cold and warm contacts as equally likely to commit after a meeting, which favors cold outreach.
- "Investor" here means someone who signs a check, not someone who is only interested.

## Result for 10 warm introductions and 50 cold emails

| If your pitch looks like | Average | None at all | 1 or more | 3 or more |
| --- | --- | --- | --- | --- |
| Prototype, no users (assumed) | 0.11 | 90% | 10% | 0% |
| Typical pre-seed (sourced) | 0.35 | 71% | 29% | 1% |
| Strong traction (assumed) | 0.62 | 55% | 45% | 3% |

For a 50 percent chance of landing at least one investor, the model needs about 92 warm introductions at the prototype rate, 27 at the typical rate and 15 with strong traction.
