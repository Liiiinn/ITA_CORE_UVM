`ifndef ITA_MHA8_REF_MODEL_SVH
`define ITA_MHA8_REF_MODEL_SVH

// Numerical contract: ITA/pyita/{ITA,util,gelu}.py. No DUT output is an operand.
`uvm_analysis_imp_decl(_ref_ctrl)
`uvm_analysis_imp_decl(_ref_stream)

class ita_mha8_ref_tile;
    ita_stream_item input_by_beat[int];
    ita_stream_item weight_by_beat[int];
    ita_stream_item bias_by_beat[int];

    int unsigned job_id;
    step_e      step;
    int unsigned head_id;
    int unsigned tile_id;
    int unsigned inner_tile_count;
endclass : ita_mha8_ref_tile

class ita_mha8_ref_model extends uvm_component;
    `uvm_component_utils(ita_mha8_ref_model)

    localparam int unsigned BEATS_PER_TILE = M * M / N;
    localparam int unsigned WEIGHT_LANES   = $bits(inp_weight_t) / WI;

    uvm_analysis_imp_ref_ctrl #(ita_ctrl_item, ita_mha8_ref_model) ctrl_imp;
    uvm_analysis_imp_ref_stream #(ita_stream_item, ita_mha8_ref_model) stream_imp;
    uvm_analysis_port #(ita_stream_item) expected_ap;

    ita_ctrl_item     config_by_job[int unsigned];
    ita_mha8_ref_tile tile_by_key[string];
    bit               finished_by_key[string];
    step_e            expected_step_by_job[int unsigned][int];
    bit               canceled_job[int unsigned];
    ita_stream_item   ow_by_key[string];

    int unsigned published;
    int unsigned errors;
    int unsigned canceled_jobs;

    function new(string name = "ita_mha8_ref_model", uvm_component parent = null);
        super.new(name, parent);
        ctrl_imp = new("ctrl_imp", this);
        stream_imp = new("stream_imp", this);
        expected_ap = new("expected_ap", this);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if ((M % N) != 0 || WEIGHT_LANES != N) begin
            `uvm_fatal("ITA_REF_GEOMETRY",
                "Online model requires M divisible by N and N weight lanes")
        end
    endfunction : build_phase

    static function bit supported(step_e step);
        return step inside {Q, K, V, OW, F1, F2, MatMul};
    endfunction : supported

    // Match PyITA floor(x + 0.5 + float32.eps), including values near half ties.
    static function longint signed requant(
        longint signed x,
        int unsigned   multiplier,
        int unsigned   right_shift,
        longint signed add
    );
        longint signed product;
        longint signed rounded;
        longint signed remainder;
        longint signed threshold;

        product = x * longint'(multiplier);

        if (right_shift == 0) begin
            rounded = product;
        end else if (right_shift >= 63) begin
            rounded = 0;
        end else if (right_shift < 23) begin
            rounded = (product >>> right_shift)
                    + ((product >> (right_shift - 1)) & 1);
        end else begin
            rounded = product >>> right_shift;
            remainder = product - (rounded <<< right_shift);
            threshold = (64'sd1 << (right_shift - 1))
                      - (64'sd1 << (right_shift - 23));
            if (remainder >= threshold)
                rounded++;
        end

        rounded += add;
        if (rounded > 127)
            return 127;
        if (rounded < -128)
            return -128;
        return rounded;
    endfunction : requant

    static function longint signed clip_acc(longint signed value);
        longint signed maximum;
        longint signed minimum;

        maximum = (64'sd1 << (WO - 1)) - 1;
        minimum = -(64'sd1 << (WO - 1));

        if (value > maximum)
            return maximum;
        if (value < minimum)
            return minimum;
        return value;
    endfunction : clip_acc

    static function longint signed activate(longint signed value, ctrl_t ctrl);
        longint signed clipped;
        longint signed absolute;
        longint signed gelu_b;
        longint signed polynomial;
        longint signed erf_value;

        if (ctrl.activation == Identity)
            return value;

        if (ctrl.activation == Relu) begin
            clipped = (value < 0) ? 0 : value;
        end else begin
            // PyITA q_1 equals q_c. Clip first to avoid abs(-128) overflow.
            clipped = (value < -127) ? -127 : value;
            gelu_b = $signed(ctrl.gelu_b);
            absolute = (clipped < 0) ? -clipped : clipped;
            if (absolute > -gelu_b)
                absolute = -gelu_b;

            polynomial = int'((absolute + gelu_b) * (absolute + gelu_b)
                             + $signed(ctrl.gelu_c));
            if (clipped < 0)
                erf_value = -polynomial;
            else if (clipped > 0)
                erf_value = polynomial;
            else
                erf_value = 0;

            clipped = int'(clipped * (erf_value + $signed(ctrl.gelu_c)));
        end

        return requant(
            clipped,
            ctrl.activation_requant_mult,
            ctrl.activation_requant_shift,
            $signed(ctrl.activation_requant_add)
        );
    endfunction : activate

    function void fail(string id, string message);
        errors++;
        `uvm_error(id, message)
    endfunction : fail

    function void write_ref_ctrl(ita_ctrl_item tr);
        ita_ctrl_item config_snapshot;

        if (config_by_job.exists(tr.job_id)) begin
            fail("ITA_REF_CTRL", $sformatf("Duplicate job_id=%0d", tr.job_id));
            return;
        end

        config_snapshot = ita_ctrl_item::type_id::create("config_snapshot");
        config_snapshot.copy(tr);

        if ($isunknown({
            config_snapshot.ctrl,
            config_snapshot.sum_eps_mult,
            config_snapshot.sum_right_shift,
            config_snapshot.sum_add,
            config_snapshot.ff_eps_mult,
            config_snapshot.ff_right_shift,
            config_snapshot.ff_add
        })) begin
            fail("ITA_REF_CTRL_X", "Unknown control/requant configuration");
            return;
        end

        foreach (config_snapshot.head_eps_mult[head_id]) begin
            if ($isunknown({
                config_snapshot.head_eps_mult[head_id],
                config_snapshot.head_right_shift[head_id],
                config_snapshot.head_add[head_id]
            })) begin
                fail("ITA_REF_CTRL_X",
                    $sformatf("Unknown requant configuration for head=%0d", head_id));
                return;
            end
        end

        config_by_job[tr.job_id] = config_snapshot;
        for (int unsigned step_index = 0; step_index < 10; step_index++) begin
            if (config_snapshot.expected_step_mask[step_index]
                && supported(step_e'(step_index))) begin
                expected_step_by_job[tr.job_id][step_index] = step_e'(step_index);
            end
        end
    endfunction : write_ref_ctrl

    function void abort_job(int unsigned job_id);
        if (canceled_job.exists(job_id))
            return;

        canceled_job[job_id] = 1'b1;
        canceled_jobs++;

        foreach (tile_by_key[key]) begin
            if (tile_by_key[key].job_id == job_id)
                tile_by_key.delete(key);
        end
        foreach (ow_by_key[key]) begin
            if (ow_by_key[key].job_id == job_id)
                ow_by_key.delete(key);
        end
    endfunction : abort_job

    function void write_ref_stream(ita_stream_item tr);
        string            tile_key;
        ita_mha8_ref_tile tile_state;
        ita_stream_item   source_snapshot;
        ita_ctrl_item     config_snapshot;
        int unsigned      beat_id;
        int unsigned      beat_index;
        int unsigned      maximum_tiles;

        if (!supported(tr.step) || canceled_job.exists(tr.job_id))
            return;

        if (!config_by_job.exists(tr.job_id)) begin
            fail("ITA_REF_NO_CTRL", tr.sprint());
            return;
        end

        config_snapshot = config_by_job[tr.job_id];
        expected_step_by_job[tr.job_id][int'(tr.step)] = tr.step;
        tile_key = $sformatf("%0d:%0d:%0d:%0d",
            tr.job_id, tr.step, tr.head_id, tr.tile_id);

        if (finished_by_key.exists(tile_key)) begin
            fail("ITA_REF_EXTRA_SOURCE", tile_key);
            return;
        end

        if (!tile_by_key.exists(tile_key)) begin
            tile_state = new;
            tile_state.job_id = tr.job_id;
            tile_state.step = tr.step;
            tile_state.head_id = tr.head_id;
            tile_state.tile_id = tr.tile_id;
            case (tr.step)
                OW:      tile_state.inner_tile_count = config_snapshot.ctrl.tile_p;
                F2:      tile_state.inner_tile_count = config_snapshot.ctrl.tile_f;
                default: tile_state.inner_tile_count = config_snapshot.ctrl.tile_e;
            endcase
            tile_by_key[tile_key] = tile_state;
        end
        tile_state = tile_by_key[tile_key];

        case (tr.step)
            OW, F2:  maximum_tiles = config_snapshot.ctrl.tile_s * config_snapshot.ctrl.tile_e;
            F1:      maximum_tiles = config_snapshot.ctrl.tile_s * config_snapshot.ctrl.tile_f;
            default: maximum_tiles = config_snapshot.ctrl.tile_s * config_snapshot.ctrl.tile_p;
        endcase

        if (tr.head_id >= 8
            || tile_state.inner_tile_count == 0
            || tr.inner_tile_id >= tile_state.inner_tile_count
            || tr.tile_id >= maximum_tiles) begin
            fail("ITA_REF_METADATA", tile_key);
            return;
        end

        // Monitor metadata is segment-local; it never depends on worker arrival order.
        beat_id = tr.beat_id;
        if (beat_id >= BEATS_PER_TILE) begin
            fail("ITA_REF_BEAT", $sformatf("%s beat=%0d", tile_key, beat_id));
            return;
        end
        beat_index = tr.inner_tile_id * BEATS_PER_TILE + beat_id;

        source_snapshot = ita_stream_item::type_id::create("source_snapshot");
        source_snapshot.copy(tr);

        case (tr.kind)
            ITA_STREAM_HEAD_INPUT,
            ITA_STREAM_FF_INPUT: begin
                if (tile_state.input_by_beat.exists(beat_index)) begin
                    fail("ITA_REF_DUP", tile_key);
                    return;
                end
                if ($isunknown(tr.inp)) begin
                    fail("ITA_REF_X", tile_key);
                    return;
                end
                tile_state.input_by_beat[beat_index] = source_snapshot;
            end

            ITA_STREAM_HEAD_WEIGHT,
            ITA_STREAM_FF_WEIGHT: begin
                if (tile_state.weight_by_beat.exists(beat_index)) begin
                    fail("ITA_REF_DUP", tile_key);
                    return;
                end
                if ($isunknown(tr.weight)) begin
                    fail("ITA_REF_X", tile_key);
                    return;
                end
                tile_state.weight_by_beat[beat_index] = source_snapshot;
            end

            ITA_STREAM_HEAD_BIAS,
            ITA_STREAM_FF_BIAS: begin
                if (tile_state.bias_by_beat.exists(beat_index)) begin
                    fail("ITA_REF_DUP", tile_key);
                    return;
                end
                if ($isunknown(tr.bias)) begin
                    fail("ITA_REF_X", tile_key);
                    return;
                end
                tile_state.bias_by_beat[beat_index] = source_snapshot;
            end

            default: begin
                fail("ITA_REF_KIND", tile_key);
                return;
            end
        endcase

        if (tile_state.input_by_beat.num()
                == tile_state.inner_tile_count * BEATS_PER_TILE
            && tile_state.weight_by_beat.num()
                == tile_state.inner_tile_count * BEATS_PER_TILE
            && tile_state.bias_by_beat.num()
                == tile_state.inner_tile_count * BEATS_PER_TILE) begin
            compute(tile_state, config_snapshot);
            finished_by_key[tile_key] = 1'b1;
            tile_by_key.delete(tile_key);
        end
    endfunction : write_ref_stream

    function void compute(ita_mha8_ref_tile tile_state, ita_ctrl_item config_snapshot);
        ita_stream_item   expected;
        ita_stream_item   weight_item;
        longint signed    accumulator;
        longint signed    input_value;
        longint signed    weight_value;
        longint signed    requant_add;
        int unsigned      requant_index;
        int unsigned      output_column;
        int unsigned      weight_index;
        int unsigned      requant_multiplier;
        int unsigned      requant_shift;

        requant_index = config_snapshot.requant_index_for_step(tile_state.step);
        if (tile_state.step inside {F1, F2}) begin
            requant_multiplier = config_snapshot.ff_eps_mult[requant_index];
            requant_shift = config_snapshot.ff_right_shift[requant_index];
            requant_add = $signed(config_snapshot.ff_add[requant_index]);
        end else begin
            requant_multiplier = config_snapshot.head_eps_mult[tile_state.head_id][requant_index];
            requant_shift = config_snapshot.head_right_shift[tile_state.head_id][requant_index];
            requant_add = $signed(config_snapshot.head_add[tile_state.head_id][requant_index]);
        end

        for (int unsigned beat_id = 0; beat_id < BEATS_PER_TILE; beat_id++) begin
            expected = ita_stream_item::type_id::create("expected");
            expected.job_id = tile_state.job_id;
            expected.step = tile_state.step;
            expected.head_id = tile_state.head_id;
            expected.tile_id = tile_state.tile_id;
            expected.inner_tile_id = tile_state.inner_tile_count - 1;
            expected.beat_id = beat_id;
            expected.kind = (tile_state.step inside {F1, F2})
                          ? ITA_STREAM_FF_OUTPUT
                          : ITA_STREAM_HEAD_OUTPUT;

            for (int unsigned lane = 0; lane < N; lane++) begin
                accumulator = 0;
                output_column = (beat_id / M) * N + lane;

                for (int unsigned inner_tile = 0;
                     inner_tile < tile_state.inner_tile_count;
                     inner_tile++) begin
                    for (int unsigned element = 0; element < M; element++) begin
                        weight_index = output_column * M + element;
                        input_value = $signed(
                            tile_state.input_by_beat[
                                inner_tile * BEATS_PER_TILE + beat_id
                            ].inp[element]
                        );
                        weight_item = tile_state.weight_by_beat[
                            inner_tile * BEATS_PER_TILE + weight_index / WEIGHT_LANES
                        ];
                        weight_value = $signed(weight_item.weight[weight_index % WEIGHT_LANES]);
                        accumulator += input_value * weight_value;
                    end
                end

                accumulator += $signed(
                    tile_state.bias_by_beat[
                        (tile_state.inner_tile_count - 1) * BEATS_PER_TILE + beat_id
                    ].bias[lane]
                );
                input_value = requant(
                    clip_acc(accumulator),
                    requant_multiplier,
                    requant_shift,
                    requant_add
                );
                if (tile_state.step == F1)
                    input_value = activate(input_value, config_snapshot.ctrl);
                expected.oup[lane] = WI'(input_value);
            end

            expected_ap.write(expected);
            published++;
            if (tile_state.step == OW)
                publish_sum(expected, config_snapshot);
        end
    endfunction : compute

    function void publish_sum(ita_stream_item expected, ita_ctrl_item config_snapshot);
        string          beat_key;
        string          head_key;
        ita_stream_item sum_expected;
        longint signed  sum_value;

        beat_key = $sformatf("%0d:%0d:%0d:%0d",
            expected.job_id,
            expected.tile_id,
            expected.inner_tile_id,
            expected.beat_id);
        head_key = $sformatf("%s:%0d", beat_key, expected.head_id);
        ow_by_key[head_key] = expected;

        for (int unsigned head_id = 0; head_id < 8; head_id++) begin
            if (!ow_by_key.exists($sformatf("%s:%0d", beat_key, head_id)))
                return;
        end

        sum_expected = ita_stream_item::type_id::create("sum_expected");
        sum_expected.copy(expected);
        sum_expected.kind = ITA_STREAM_SUM_OUTPUT;
        sum_expected.head_id = 0;

        for (int unsigned lane = 0; lane < N; lane++) begin
            sum_value = 0;
            for (int unsigned head_id = 0; head_id < 8; head_id++) begin
                sum_value += $signed(
                    ow_by_key[$sformatf("%s:%0d", beat_key, head_id)].oup[lane]
                );
            end
            sum_expected.oup[lane] = WI'(requant(
                sum_value,
                config_snapshot.sum_eps_mult,
                config_snapshot.sum_right_shift,
                $signed(config_snapshot.sum_add)
            ));
        end

        expected_ap.write(sum_expected);
        published++;
        for (int unsigned head_id = 0; head_id < 8; head_id++)
            ow_by_key.delete($sformatf("%s:%0d", beat_key, head_id));
    endfunction : publish_sum

    function bit missing_tiles();
        int unsigned expected_tile_count;
        int unsigned expected_head_count;
        string       tile_key;

        foreach (expected_step_by_job[job_id, step_index]) begin
            if (canceled_job.exists(job_id))
                continue;

            case (expected_step_by_job[job_id][step_index])
                OW, F2: begin
                    expected_tile_count = config_by_job[job_id].ctrl.tile_s
                                        * config_by_job[job_id].ctrl.tile_e;
                end
                F1: begin
                    expected_tile_count = config_by_job[job_id].ctrl.tile_s
                                        * config_by_job[job_id].ctrl.tile_f;
                end
                default: begin
                    expected_tile_count = config_by_job[job_id].ctrl.tile_s
                                        * config_by_job[job_id].ctrl.tile_p;
                end
            endcase

            expected_head_count = (expected_step_by_job[job_id][step_index]
                                   inside {F1, F2}) ? 1 : 8;
            for (int unsigned head_id = 0;
                 head_id < expected_head_count;
                 head_id++) begin
                for (int unsigned tile_id = 0;
                     tile_id < expected_tile_count;
                     tile_id++) begin
                    tile_key = $sformatf("%0d:%0d:%0d:%0d",
                        job_id, step_index, head_id, tile_id);
                    if (!finished_by_key.exists(tile_key))
                        return 1'b1;
                end
            end
        end
        return 1'b0;
    endfunction : missing_tiles

    function bit pending();
        return tile_by_key.num() != 0
            || ow_by_key.num() != 0
            || missing_tiles();
    endfunction : pending

endclass : ita_mha8_ref_model

`endif // ITA_MHA8_REF_MODEL_SVH
