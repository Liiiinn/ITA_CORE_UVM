# ITA MHA8 UVM Verification

## 项目简介

本项目为 ITA（Integer Transformer Accelerator）MHA8 顶层搭建 SystemVerilog/UVM 验证平台。DUT 包含 8 个 attention head、head sum 和 feed-forward 路径，主要计算阶段包括：

- Q/K/V projection
- QK 与 softmax
- AV
- Output Weight projection（OW）
- Feed-forward F1/F2
- Linear/MatMul
- SingleAttention

验证平台采用分层策略：

- **Online UVM**：检查 valid-ready 协议、transaction metadata、segment/beat 数量、顺序、重复/缺失、X/Z、reset 和 timeout。
- **SVA**：检查 cycle-level 协议以及 backpressure 下 valid、payload 和 metadata 的稳定性。
- **Offline Python/PyITA**：生成 tensor、weight、bias、requant 参数和 expected output，并比较 RTL actual output。
- **Coverage**：收集 functional/assertion coverage，并可选择收集 DUT RTL code coverage。

当前活动验证代码位于 `tb/`。`tbbak/` 是历史备份，不参与 `sim/filelist.f` 编译。

## 目录结构

```text
ITA_CORE_UVM/
|-- dut/                         # ITA/MHA8 RTL
|-- tb/
|   |-- agents/                  # ctrl 与可复用 stream agents
|   |-- common/                  # scenario、core item、step payload
|   |-- cov/                     # functional coverage
|   |-- env/                     # env、env_config、virtual sequencer
|   |-- if/                      # DUT interface 与 SVA
|   |-- log/                     # actual CSV logger
|   |-- pred/                    # structural predictor
|   |-- scb/                     # structural scoreboard
|   |-- seq/                     # leaf sequences
|   |-- tests/                   # UVM tests
|   |-- tools/                   # case/vector/compare Python 工具
|   |-- top/                     # testbench top
|   `-- vseq/                    # virtual sequences
|-- sim/
|   |-- cases/                   # regression manifests
|   |-- coverage/                # code coverage waiver 记录
|   |-- scripts/                 # compile/smoke/regression scripts
|   |-- logger/                  # 生成的 CSV 与 manifest
|   `-- output/                  # logs、UCDB 与 reports
`-- tbbak/                       # 历史备份
```

### Scenario 与 test

`ita_mha8_scenario_cfg` 是 testcase intent 和 plusarg 的统一配置源，保存 vector 路径、layer、activation、tile、protocol random、backpressure、timeout、coverage target 和 negative fault 等参数。

base test 负责创建 scenario、env config 和 env，并统一启动 vseq。Derived test 只保留自身的 scenario defaults、vseq 类型和 vector 加载差异。

### Agent 与 vseq

`ita_ctrl_agent` 负责控制 transaction。`ita_stream_agent` 复用于 8 个 head 的 input、weight、bias、output，以及 sum/FF streams。

`ita_mha8_vsequencer` 保存各 agent sequencer handle。`ita_mha8_vsequence::execute_core_job()` 统一处理 layer dispatch、ctrl update、stream sequencing、output-ready policy 和 completion wait。

Protocol-random vseq 在一次仿真中生成多个 deterministic mini-jobs，再复用统一 job 执行入口。

### Predictor、scoreboard 与 SVA

Structural predictor 根据 ctrl/tile 配置推导 expected segment、beat 和 metadata 合法范围。

Scoreboard 检查：

- step/head/tile/inner/beat metadata
- source/output segment count
- missing、duplicate、discontinuous/out-of-order beat
- X/Z、bias 规则、reset abort 和 timeout

SVA 负责 valid-ready、backpressure stability、ctrl/tile/reset 等 cycle-level 协议检查。

Scoreboard 不重复实现完整 attention、softmax、GELU 和 quantization 数值模型；numerical correctness 由 PyITA/offline compare 负责。

## Regression Cases

`sim/cases/` 当前包含：

| Manifest | Cases | 用途 |
|---|---:|---|
| `random_mha8_cases.json` | 10 | Python numerical random 与 offline compare |
| `protocol_random_mha8_cases.json` | 4 | 多 mini-job protocol/structural random |
| `protocol_directed_mha8_cases.json` | 15 | backpressure、tile boundary、计算模式与 targeted coverage |
| `numerical_corner_mha8_cases.json` | 12 | requant、bias、softmax、sparse/zero corner cases |
| `negative_mha8_cases.json` | 19 | valid-ready fault、illegal tile/metadata/beat、output starvation |

Negative case 采用 XFAIL：仿真必须非零退出，并且 `vsim.log` 必须精确命中指定 checker tag，才判定为 `XFAIL_PASS`。Negative UCDB 不参与 legal coverage merge。

## 环境准备

需要 QuestaSim 的 `vlib`、`vmap`、`vlog`、`vsim` 和 `vcover` 可从 `PATH` 找到，也可通过 `-QuestaBin` 指定工具目录。

### ITA / PyITA tensor 依赖

Numerical test 使用的原始 tensor 和 golden **仍由[原 ITA 仓库](https://github.com/pulp-platform/ITA/)生成**，ITA_CORE_UVM 没有另行实现一套 tensor generator。两个仓库应保持相邻目录结构：

```text
workspace/
|-- ITA/
|   |-- testGenerator.py         # 原始 tensor/golden 生成入口
|   |-- PyITA/                   # Python numerical model
|   `-- simvectors/
|       `-- data_.../standalone/ # input/weight/bias/requant/expected
`-- ITA_CORE_UVM/
    |-- tb/tools/                # UVM vector adapter 与 case generators
    `-- sim/
```

完整 numerical vector flow 为：

```text
ITA/testGenerator.py
  -> ITA/simvectors/data_.../standalone
  -> ITA_CORE_UVM/tb/tools/gen_mha8_pyita_vectors.py
  -> UVM stream CSV + requant CSV + compare manifest
  -> UVM simulation
  -> actual CSV
  -> compare_mha8_manifest.py
```

- `gen_random_mha8_cases.py` 和 `gen_directed_mha8_cases.py` 会先检查 `ITA/simvectors` 中是否存在所需 shape/pattern。
- 缺失 vector 且未指定 `--no-auto-generate` 时，generator 会调用 `../ITA/testGenerator.py`。
- `smoke.ps1 -GenerateVectors` 负责把 `-PyitaDir` 指向的 standalone 数据适配为 UVM 输入，不负责重新计算原始 tensor/golden。
- `protocol_random_mha8_cases.json` 使用 SV deterministic payload，不依赖完整 PyITA tensor，也不进行 offline numerical compare。

例如，可直接使用原 ITA generator 生成一个基础 MHA8 vector：

```powershell
python ..\ITA\testGenerator.py `
  --seed 0 `
  -S 64 -E 64 -P 64 -F 64 -H 8 `
  --activation relu
```

随后由 case generator 或 `smoke.ps1` 调用 UVM adapter。正常情况下不需要手工重复执行这两个阶段。

Numerical vector generation 需要 Python/PyITA 依赖：

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r ..\ITA\requirements.txt
```

所有命令建议从 `ITA_CORE_UVM` 根目录执行。Python generator 应使用 `python script.py` 调用，不要依赖 Windows 的 `.py` 文件关联。

## 常用命令

### 编译

```powershell
.\sim\scripts\compile.ps1
```

启用 RTL code coverage instrumentation：

```powershell
.\sim\scripts\compile.ps1 `
  -EnableCodeCoverage `
  -CodeCoverageSpec sbceft
```

### 最小 protocol smoke

```powershell
.\sim\scripts\smoke.ps1 `
  -TestName ita_mha8_protocol_random_test `
  -ProtocolNumJobs 1 `
  -ProtocolTileMin 1 `
  -ProtocolTileMax 1 `
  -ProtocolProjection ATTNFF `
  -NoGenerateVectors `
  -NoCompare
```

### 生成 cases

```powershell
# Numerical random
python .\tb\tools\gen_random_mha8_cases.py `
  --count 10 `
  --seed 7 `
  --shape-values 64,128,192,256 `
  --out .\sim\cases\random_mha8_cases.json

# Protocol random
python .\tb\tools\gen_protocol_random_mha8_cases.py `
  --count 4 `
  --jobs-min 8 `
  --jobs-max 16 `
  --tile-max 2 `
  --out .\sim\cases\protocol_random_mha8_cases.json

# Protocol directed / numerical corner / negative
python .\tb\tools\gen_directed_mha8_cases.py --suite protocol
python .\tb\tools\gen_directed_mha8_cases.py --suite numerical
python .\tb\tools\gen_directed_mha8_cases.py --suite negative
```

### 运行 regression

```powershell
.\sim\scripts\run_mha8_regression.ps1 `
  -CasesManifest .\sim\cases\protocol_random_mha8_cases.json `
  -StopOnFirstFail
```

替换 `-CasesManifest` 即可运行其他 suite。常用选项：

- `-DryRun`：只展开命令
- `-OutDir <path>`：指定输出目录
- `-Resume`：复用同一输出目录中经过校验的 PASS case
- `-EnableCodeCoverage`：收集 RTL code coverage
- `-CodeCoverageSpec sbceft`：设置 coverage metrics

### 完整 legal code coverage flow

```powershell
.\sim\scripts\run_mha8_code_coverage.ps1 `
  -CodeCoverageSpec sbceft `
  -StopOnFirstFail
```

该脚本依次运行 protocol directed、protocol random、numerical random 和 numerical corner，并检查 DUT RTL fingerprint 后合并 legal UCDB。

## 输出文件

单次 smoke log：

```text
sim/output/logs/<test_name>.log
```

Regression 主要输出：

```text
sim/output/random_regression/<timestamp>/
|-- 000_<case>/
|   |-- smoke_wrapper.log
|   |-- vsim.log
|   |-- case_result.json
|   `-- <case>.ucdb
|-- coverage/
|   |-- random_mha8_merged.ucdb
|   |-- coverage_report.txt
|   `-- coverage_html/
|-- regression_summary.json
`-- regression_summary.txt
```

Code coverage closure 输出位于：

```text
sim/output/code_coverage_closure/<timestamp>/coverage/
```

其中包含 merged UCDB、functional/code coverage text/HTML report 和 provenance。

## 验证边界

- Numerical golden 依赖 PyITA/offline compare，当前没有可用的 online full numerical reference model。
- Functional、assertion 和 code coverage 是不同指标；单一 coverage 数字不能证明完整 verification closure。
- Legal protocol-random 遵循 DUT 当前的 source bundle 合约；非法 valid-ready 行为由 negative suite 单独验证。
- 当前部分 base/coverage-target 路径仍有 direct-VIF 操作，尚未将所有 driven signal 完全收敛为 driver 唯一 owner。
- Negative/XFAIL 证明 checker 能发现指定 fault，不代表 DUT 支持非法输入后的功能恢复。
- 大 shape、toggle coverage 和全量 numerical regression 仿真成本较高，应根据 coverage gap 选择性执行。
