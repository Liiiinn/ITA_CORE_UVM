# ITA MHA8 UVM learning skeleton

This directory is intentionally minimal. It is a learning copy of `tb`, not the
full MHA8 verification environment.

## Current scope

- Keep only the basic UVM hierarchy: top, interface, test, env, ctrl agent, and
  one stream agent.
- Do not add scoreboard, reference model, coverage, virtual sequence, or MHA8
  multi-head expansion until the previous learning stage is clear.
- Compile only package `.sv` files, interfaces, top modules, and RTL. Do not add
  `.svh` files directly to `sim/filelist.f`.

## Growth path

1. Add a minimal ctrl sequence.
2. Add one stream transaction.
3. Connect stream monitor analysis output to a simple checker or logger.
4. Add a simple output monitor.
5. Add a scoreboard.
6. Expand stream agents to all 8 MHA heads.
7. Add MHA8-specific reference or golden comparison.
