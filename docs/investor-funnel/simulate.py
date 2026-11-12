"""
Investor funnel simulation for Loopd.

This does NOT predict how many investors Loopd will get. It shows what a typical
fundraising funnel produces for the outreach you describe, with the uncertainty in
every rate left visible. Change the numbers at the top or pass them on the command line.

Each contact has to pass three steps, one after another:
    reply to you  ->  show up to a meeting  ->  put money in
Given the rates, every contact passes all three with probability reply * show * commit,
so investors found ~ Binomial(contacts, that probability). Each trial first draws the
rates from their ranges, because we do not know the true rates.

Run:  python3 simulate.py
      python3 simulate.py --warm 10 --cold 50
"""
import argparse
import random

# ---- Rates (low, high). Each trial draws uniformly between them. ----------------------

# Reply rates. Source: blog posts on investor outreach (vendor content, not studies).
#   warm intro replies 20 to 40 percent, cold replies 1 to 5 percent
REPLY_WARM = (0.20, 0.40)
REPLY_COLD = (0.01, 0.05)

# Meeting show rates. Source: same kind of blog. Warm 85 to 95 percent, cold 50 to 60.
SHOW_WARM = (0.85, 0.95)
SHOW_COLD = (0.50, 0.60)

# Meeting to signed check. This is the number that matters most and the least certain.
#   typical:   5 to 15 percent of first meetings. Source: Allied Venture Partners'
#              investor pipeline calculator, for pre-seed founders who are raising.
#   prototype: MY ASSUMPTION for an unlaunched app with no users and one developer.
#   traction:  MY ASSUMPTION for a launched app with clear growth.
COMMIT_PROFILES = {
    "prototype, no users (assumed)": (0.01, 0.05),
    "typical pre-seed (sourced)": (0.05, 0.15),
    "strong traction (assumed)": (0.10, 0.25),
}


def binomial(n, p, rng):
    return sum(1 for _ in range(n) if rng.random() < p)


def one_trial(warm, cold, commit_range, rng):
    commit = rng.uniform(*commit_range)
    p_warm = rng.uniform(*REPLY_WARM) * rng.uniform(*SHOW_WARM) * commit
    p_cold = rng.uniform(*REPLY_COLD) * rng.uniform(*SHOW_COLD) * commit
    return binomial(warm, p_warm, rng) + binomial(cold, p_cold, rng)


def run(warm, cold, commit_range, trials, seed):
    rng = random.Random(seed)
    results = sorted(one_trial(warm, cold, commit_range, rng) for _ in range(trials))
    n = len(results)
    return {
        "mean": sum(results) / n,
        "median": results[n // 2],
        "p0": sum(1 for r in results if r == 0) / n,
        "p1": sum(1 for r in results if r >= 1) / n,
        "p3": sum(1 for r in results if r >= 3) / n,
        "p90": results[int(n * 0.9)],
    }


def chance_of_at_least_one(contacts, per_contact_ranges, commit_range, samples, seed):
    """P(at least one investor) when every contact is of one kind (all warm or all cold)."""
    rng = random.Random(seed)
    total = 0.0
    for _ in range(samples):
        commit = rng.uniform(*commit_range)
        reply = rng.uniform(*per_contact_ranges[0])
        show = rng.uniform(*per_contact_ranges[1])
        p = reply * show * commit
        total += 1 - (1 - p) ** contacts
    return total / samples


def contacts_needed(per_contact_ranges, commit_range, target=0.5, samples=4000, seed=7):
    for n in range(1, 2001):
        if chance_of_at_least_one(n, per_contact_ranges, commit_range, samples, seed) >= target:
            return n
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--warm", type=int, default=10, help="warm introductions you can get")
    ap.add_argument("--cold", type=int, default=50, help="cold emails you will send")
    ap.add_argument("--trials", type=int, default=20000)
    ap.add_argument("--seed", type=int, default=1)
    args = ap.parse_args()

    print(f"Outreach: {args.warm} warm introductions and {args.cold} cold emails")
    print(f"{args.trials:,} simulated fundraising attempts per row\n")

    head = f"{'If your pitch looks like':32} {'average':>8} {'none at all':>12} {'1 or more':>10} {'3 or more':>10} {'lucky 1 in 10':>14}"
    print(head)
    print("-" * len(head))
    for name, commit in COMMIT_PROFILES.items():
        r = run(args.warm, args.cold, commit, args.trials, args.seed)
        print(f"{name:32} {r['mean']:8.2f} {r['p0']*100:11.0f}% {r['p1']*100:9.0f}% {r['p3']*100:9.0f}% {r['p90']:14d}")

    print("\nHow many contacts for a 50 percent chance of at least one investor")
    head2 = f"{'If your pitch looks like':32} {'warm intros':>12} {'cold emails':>12}"
    print(head2)
    print("-" * len(head2))
    for name, commit in COMMIT_PROFILES.items():
        w = contacts_needed((REPLY_WARM, SHOW_WARM), commit)
        c = contacts_needed((REPLY_COLD, SHOW_COLD), commit)
        print(f"{name:32} {str(w):>12} {str(c):>12}")

    print("\nRead this as a map of how outreach turns into investors, not a forecast.")
    print("It ignores the idea, team, timing, market and check size, and it ignores friends")
    print("and family, who invest because they know you and not because of a funnel.")


if __name__ == "__main__":
    main()
