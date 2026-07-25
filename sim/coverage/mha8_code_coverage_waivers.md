# MHA8 Code Coverage Waiver Audit

本清单用于审计潜在 unreachable code，不会自动修改 UCDB，也不会生成 waiver 后的覆盖率。
`code_coverage_report.txt` 始终保留 raw coverage；只有经过 RTL/DV 共同审核并将状态改为 `APPROVED` 的条目，才可在后续版本考虑转为 Questa exclusion。

## 状态定义

| 状态 | 含义 |
|---|---|
| `PROPOSED` | 已有代码证据，但尚未获得设计审核批准 |
| `APPROVED` | 已确认不属于当前 MHA8 integration verification target |
| `REJECTED` | 路径可达或属于验证需求，必须增加 testcase |

## 当前候选项

| ID | Design unit / symbol | 代码证据 | 当前判断 | 状态 |
|---|---|---|---|---|
| `MHA8-COV-W001` | `ita_mha8.phase_mismatch_o` | 八个 head 接收相同 ctrl；该分支要求 all-valid 时内部 step 不一致 | defensive integration path，需 RTL owner 确认可达性 | `PROPOSED` |
| `MHA8-COV-W002` | `ita_serdiv.opcode_i` signed/remainder modes | `ita_softmax_top` 将 `opcode_i` 固定为 `2'b00` | 顶层不可选择；若 divider 可复用，应由 unit-level TB 验证 | `PROPOSED` |
| `MHA8-COV-W003` | `ita_serdiv.flush_i` | `ita_softmax_top` 将 `flush_i` 固定为 `1'b0` | 不属于当前 MHA8 integration contract | `PROPOSED` |
| `MHA8-COV-W004` | `ita_controller.softmax_div` | 最大合法连续 QK 输入下，AV 开始前 division 已完成 | 当前参数下疑似不可达，仍需参数级证明 | `PROPOSED` |
| `MHA8-COV-W005` | softmax FIFO full/stall | 10 个 divider 的消费带宽使 occupancy 未达到 `SoftFifoDepth` | 当前集成参数下疑似不可达 | `PROPOSED` |
| `MHA8-COV-W006` | physical output FIFO full | `ongoing_q >= FifoDepth` 先触发 source stall，实测 `output_stall=1/full=0` | integration 保护使 full 疑似不可达 | `PROPOSED` |

机器可读的完整 reason、impact、owner 和 review 字段位于 `mha8_code_coverage_waivers.json`。

## 明确不得 Waive

- `ita_controller` 的运行中 reset transition，例如 `Q/K/V/QK/AV/F1 -> Idle`。这些路径在结构上可达，应先确认 reset requirement，再决定是否增加 targeted reset test。
- `Linear/MatMul` 和 `SingleAttention/QK->AV`。RTL enum、controller 和 ctrl SVA 均包含这些模式，本次通过 legal directed case 补齐。
- numerical corner 未命中的可达 arithmetic branch。应先运行带 code instrumentation 的 Numerical Corner，再根据 DU detail report 分类。

## Ownership 待复核

`fifo_v3`、`tc_sram`、`cluster_clk_cells` 和 `tc_clk` 暂不自动排除。需要先确认它们是项目自研 RTL、复用 IP 还是仿真模型，并明确其 coverage owner。

## 审核流程

1. 使用同一 DUT source fingerprint 运行 legal code coverage closure。
2. 从 `code_coverage_du_details.txt` 定位 zero bin，并关联到具体 requirement。
3. 对可达路径增加 targeted testcase；不得为了提高数字而 waiver。
4. 对不可达候选项记录 RTL 连接、固定参数或 generate 条件证据。
5. RTL/DV owner 审核后更新 JSON 状态和日期；第一版仍不自动应用 exclusion。
