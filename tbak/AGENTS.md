# ITA_CORE_UVM/tbak Exercise Skeleton

`tbak` is the learning version of the ITA/MHA8 UVM testbench. It should compile and start UVM, but important behavior is intentionally left as `TODO Stage N` exercises. Use `tb` as the reference implementation and do not edit it while working in `tbak`.

## Ground Rules

- Keep the DUT target as `ita_mha8`; learn through head0 first.
- Preserve names and package style from `tb` where practical.
- Do not add `tbak/seq`, `tbak/scb`, or `tbak/log` to the active filelist until their stage.
- Add code directly below the matching TODO instead of replacing the whole skeleton.
- After each stage, run dry-run first, then smoke.

## Stage Order

1. Baseline smoke shell
   - Files: `top/ita_mha8_tb_top.sv`, `if/ita_mha8_if.sv`, `env/ita_mha8_env.svh`, `tests/ita_mha8_base_test.svh`.
   - Goal: compile and start `ita_base_test` with no real sequence.

2. Shared MHA8 ctrl path
   - Files: `agents/ita_ctrl_agent/ita_ctrl_item.svh`, `ita_ctrl_driver.svh`, `ita_ctrl_monitor.svh`, `tests/ita_mha8_base_test.svh`.
   - Goal: create one ctrl item, drive `ctrl_i` and a one-cycle `start` pulse, and monitor the transaction.
   - Start here before stream, logger, or scoreboard work.

3. Head0 input stream
   - Files: `agents/ita_stream_agent/ita_stream_item.svh`, `ita_stream_driver.svh`, `ita_stream_monitor.svh`, `env/ita_mha8_env_config.svh`.
   - Goal: drive and monitor only `input_agt[0]`.

4. Head0 weight/bias streams
   - Files: same stream agent files plus test stimulus.
   - Goal: reuse the same stream agent for `weight_agt[0]` and `bias_agt[0]`.

5. Head0 output stream
   - Files: `ita_stream_driver.svh`, `ita_stream_monitor.svh`, `env/ita_mha8_env.svh`.
   - Goal: drive output ready and sample `per_head_valid_o[0] && per_head_ready_i[0]`.

6. Core-level transaction
   - File: `common/ita_mha8_core_item.svh`.
   - Goal: describe layer, activation, tile parameters, payloads, and compare paths, then split into ctrl + stream items.

7. Logger
   - Files: env connect phase and a logger component restored or created under `tbak/log`.
   - Goal: passively dump actual output from head0 first.

8. Smoke scoreboard and early assertions
   - Files: interface assertion hooks, scoreboard skeleton, env connect phase.
   - Goal: check count, X/Z, timeout, valid-ready, and backpressure stability.

9. Linear directed testcase
   - Files: tests, core item, ctrl/stream sequences.
   - Goal: run a small manually checkable Linear testcase on head0.

10. Phase 2 compare path
    - Files: common item, logger, test flow, scripts if needed.
    - Goal: connect actual output to Python compare.

11. Full MHA8 expansion
    - Files: env config, stream config, logger, scoreboard, reference model.
    - Goal: enable heads 1-7, sum path, feed-forward path, and full golden compare.

## Verification Commands

List TODOs:

```powershell
Select-String -Path ITA_CORE_UVM\tbak\**\*.sv,ITA_CORE_UVM\tbak\**\*.svh,ITA_CORE_UVM\tbak\AGENTS.md -Pattern "TODO Stage"
```

Check that complex packages are not active:

```powershell
Select-String -Path ITA_CORE_UVM\sim\filelist.f,ITA_CORE_UVM\tbak\env\*.sv,ITA_CORE_UVM\tbak\tests\*.sv -Pattern "ita_mha8_scb_pkg|ita_mha8_seq_pkg|ref_model|scoreboard|transaction_logger"
```

Dry-run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ITA_CORE_UVM\sim\scripts\smoke.ps1 -DryRun
```

Smoke:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ITA_CORE_UVM\sim\scripts\smoke.ps1
```
