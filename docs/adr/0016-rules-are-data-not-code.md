# 16. Stocking rules are data, owned by the person who keeps fish

**Status:** Accepted · **Phase:** 5

## Context

`aquatics-advisor` decides whether a tank will work. Every judgement it makes rests on a number
somebody chose: how much temperature overlap is enough, how many litres per centimetre of adult
fish, at what size ratio one fish eats another.

Those numbers are not engineering decisions. They are the shop's opinion, they are argued about, and
they change far more often than the code that applies them.

## Decision

Every threshold lives in `rules/rules.yaml`, with a plain-English justification beside it. The Python
decides *what* to check; the YAML decides *how much is too much*.

The justifications are not comments — the API quotes them back to the customer. A rule that cannot
explain itself in a sentence an aquarist would use is a rule that should not be in the file.

Consequences that follow from treating them as data:

- **Every response carries `rulesVersion`**, and `GET /v1/rules` publishes the file. A customer told
  "no" can see the threshold that said so.
- **The test suite loads the shipped YAML**, not a fixture. Widening the pH tolerance until guppies
  and cardinal tetras pass turns a test red, and whoever did it has to say so out loud.
- **The rules are read once, at startup, and never reloaded on a timer.** A file changing underneath
  a running service means two pods answer the same question differently for the length of a rollout,
  and "why did it say yes yesterday?" stops being answerable. A rules change is a deployment.

This is also the reason the service is Python and releases on its own cadence: "change a threshold
and ship it this afternoon" is a different rhythm from the rest of the platform.

## Consequences

The domain expert can change the shop's advice without a developer, and the change is reviewable by
someone who knows fish rather than someone who knows the codebase.

**Cost:** a YAML file is not type-checked. A missing key is a `KeyError` at request time rather than
a compile error, and the only thing standing between a typo and a 500 is the test suite loading the
real file. A schema for the rules would close that, and it is not written.

**Cost:** the split is not free of judgement. "Which species nip fins" ended up in the YAML as a
list of SKUs, because it is a property of the animal that the catalog does not record — which means
the rules file now carries a small amount of *data* as well as thresholds. That is a compromise, and
the right fix is a field on the catalog's species profile.
