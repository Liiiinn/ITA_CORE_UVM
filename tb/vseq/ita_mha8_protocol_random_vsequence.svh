`ifndef ITA_MHA8_PROTOCOL_RANDOM_VSEQUENCE_SVH
`define ITA_MHA8_PROTOCOL_RANDOM_VSEQUENCE_SVH

class ita_mha8_protocol_random_vsequence extends ita_mha8_vsequence;
    `uvm_object_utils(ita_mha8_protocol_random_vsequence)
    `uvm_declare_p_sequencer(ita_mha8_vsequencer)

    int unsigned num_jobs = 8;
    int unsigned tile_min = 1;
    int unsigned tile_max = 2;
    int unsigned start_gap_max = 0;
    string projection_mode = "ATTNFF";

    function new(string name = "ita_mha8_protocol_random_vsequence");
        super.new(name);
    endfunction : new

    virtual task body();
        load_protocol_random_plusargs();

        for (int unsigned job_id = 0; job_id < num_jobs; job_id++) begin
            build_protocol_core(job_id, core);
            stop_head_output_ready = 1'b0;

            `uvm_info("PROTOCOL_RAND",
                $sformatf("Starting protocol job=%0d projection=%s activation=%s tile_s/e/p/f=%0d/%0d/%0d/%0d",
                    job_id,
                    projection_mode,
                    core.activation.name(),
                    core.tile_s,
                    core.tile_e,
                    core.tile_p,
                    core.tile_f),
                UVM_LOW)

            fork
                drive_head_output_ready_bundle();
                begin
                    fork
                        send_attention_phase_if_present();
                        wait_attention_sum_complete();
                    join

                    if (has_ff_steps()) begin
                        fork
                            send_feedforward_phase();
                            wait_feedforward_complete();
                        join
                    end

                    stop_head_output_ready = 1'b1;
                end
            join_any
            disable fork;

            wait_protocol_start_gap();
        end
    endtask : body

    function void load_protocol_random_plusargs();
        void'($value$plusargs("ITA_NUM_JOBS=%d", num_jobs));
        void'($value$plusargs("ITA_PROTOCOL_TILE_MIN=%d", tile_min));
        void'($value$plusargs("ITA_PROTOCOL_TILE_MAX=%d", tile_max));
        void'($value$plusargs("ITA_PROTOCOL_START_GAP_MAX=%d", start_gap_max));
        void'($value$plusargs("ITA_PROTOCOL_PROJECTION=%s", projection_mode));
        void'($value$plusargs("ITA_SOURCE_GAP_MAX=%d", source_gap_max));
        void'($value$plusargs("ITA_INPUT_SOURCE_GAP_MAX=%d", input_source_gap_max));
        void'($value$plusargs("ITA_WEIGHT_SOURCE_GAP_MAX=%d", weight_source_gap_max));
        void'($value$plusargs("ITA_BIAS_SOURCE_GAP_MAX=%d", bias_source_gap_max));
        void'($value$plusargs("ITA_GROUP_IDLE_GAP_MIN=%d", group_idle_gap_min));
        void'($value$plusargs("ITA_GROUP_IDLE_GAP_MAX=%d", group_idle_gap_max));
        load_sink_backpressure_plusargs();
        load_output_timeout_plusargs();

        if (num_jobs == 0)
            num_jobs = 1;
        if (tile_min < 1)
            tile_min = 1;
        if (tile_max > 4)
            tile_max = 4;
        if (tile_max < tile_min)
            tile_max = tile_min;
        if (group_idle_gap_max < group_idle_gap_min)
            group_idle_gap_max = group_idle_gap_min;
    endfunction : load_protocol_random_plusargs

    task send_attention_phase_if_present();
        if (first_attention_step_or_idle() != Idle)
            send_attention_phase();
    endtask : send_attention_phase_if_present

    function step_e first_attention_step_or_idle();
        foreach (core.step_order[i]) begin
            if (is_attention_step(core.step_order[i]))
                return core.step_order[i];
        end
        return Idle;
    endfunction : first_attention_step_or_idle

    task wait_protocol_start_gap();
        int unsigned gap_cycles;

        if (start_gap_max == 0)
            return;

        gap_cycles = $urandom_range(start_gap_max, 0);
        repeat (gap_cycles) begin
            @(posedge p_sequencer.vif.clk_i);
        end
    endtask : wait_protocol_start_gap

    task build_protocol_core(int unsigned job_id, output ita_mha8_core_item protocol_core);
        string selected_projection;
        bit include_attention;
        bit include_ff;

        protocol_core = ita_mha8_core_item::type_id::create($sformatf("protocol_core_%0d", job_id));
        protocol_core.tile_s = tile_t'($urandom_range(tile_max, tile_min));
        protocol_core.tile_e = tile_t'($urandom_range(tile_max, tile_min));
        protocol_core.tile_p = tile_t'($urandom_range(tile_max, tile_min));
        protocol_core.tile_f = tile_t'($urandom_range(tile_max, tile_min));
        protocol_core.activation = random_activation();
        protocol_core.clear_requant_config();

        selected_projection = projection_mode.toupper();
        include_attention = 1'b0;
        include_ff = 1'b0;
        if (selected_projection == "RANDOM") begin
            case ($urandom_range(2))
                0: include_attention = 1'b1;
                1: include_ff = 1'b1;
                default: begin
                    include_attention = 1'b1;
                    include_ff = 1'b1;
                end
            endcase
        end else if (selected_projection == "ATTN") begin
            include_attention = 1'b1;
        end else if (selected_projection == "FF") begin
            include_ff = 1'b1;
        end else begin
            include_attention = 1'b1;
            include_ff = 1'b1;
        end

        if (include_attention) begin
            protocol_core.layer = Attention;
            add_protocol_step(protocol_core, Q, job_id);
            add_protocol_step(protocol_core, K, job_id);
            add_protocol_step(protocol_core, V, job_id);
            add_protocol_step(protocol_core, QK, job_id);
            add_protocol_step(protocol_core, AV, job_id);
            add_protocol_step(protocol_core, OW, job_id);
        end

        if (include_ff) begin
            if (!include_attention)
                protocol_core.layer = Feedforward;
            add_protocol_step(protocol_core, F1, job_id);
            add_protocol_step(protocol_core, F2, job_id);
        end

    endtask : build_protocol_core

    function activation_e random_activation();
        case ($urandom_range(2))
            0: return Identity;
            1: return Relu;
            default: return Gelu;
        endcase
    endfunction : random_activation

    task add_protocol_step(
        ita_mha8_core_item protocol_core,
        step_e step,
        int unsigned job_id
    );
        int unsigned tile_count;
        int unsigned inner_count;
        int unsigned beats_per_segment;

        protocol_core.add_step_to_order(step);
        tile_count = protocol_tile_count(protocol_core, step);
        inner_count = protocol_inner_count(protocol_core, step);
        beats_per_segment = M * M / N;

        for (int unsigned tile_id = 0; tile_id < tile_count; tile_id++) begin
            for (int unsigned inner_id = 0; inner_id < inner_count; inner_id++) begin
                ita_mha8_step_payload payload;

                payload = protocol_core.create_schedule_payload(step, tile_id, inner_id);
                for (int unsigned beat_id = 0; beat_id < beats_per_segment; beat_id++) begin
                    if (payload.drive_head_streams) begin
                        for (int unsigned head_id = 0; head_id < 8; head_id++) begin
                            payload.input_payload_by_head[head_id].push_back(
                                protocol_input_payload(job_id, step, head_id, tile_id, inner_id, beat_id));
                            payload.weight_payload_by_head[head_id].push_back(
                                protocol_weight_payload(job_id, step, head_id, tile_id, inner_id, beat_id));
                            payload.bias_payload_by_head[head_id].push_back(
                                protocol_bias_payload(job_id, step, head_id, tile_id, inner_id, beat_id, inner_count));
                        end
                    end else begin
                        payload.ff_input_payload.push_back(
                            protocol_input_payload(job_id, step, 0, tile_id, inner_id, beat_id));
                        payload.ff_weight_payload.push_back(
                            protocol_weight_payload(job_id, step, 0, tile_id, inner_id, beat_id));
                        payload.ff_bias_payload.push_back(
                            protocol_bias_payload(job_id, step, 0, tile_id, inner_id, beat_id, inner_count));
                    end
                end
                payload.validate_complete();
            end
        end
    endtask : add_protocol_step

    function int unsigned protocol_tile_count(ita_mha8_core_item protocol_core, step_e step);
        case (step)
            Q, K, V: return protocol_core.tile_s * protocol_core.tile_p;
            QK:      return protocol_core.tile_s * protocol_core.tile_s;
            AV:      return protocol_core.tile_s * protocol_core.tile_p;
            OW:      return protocol_core.tile_s * protocol_core.tile_e;
            F1:      return protocol_core.tile_s * protocol_core.tile_f;
            F2:      return protocol_core.tile_s * protocol_core.tile_e;
            default: return 0;
        endcase
    endfunction : protocol_tile_count

    function int unsigned protocol_inner_count(ita_mha8_core_item protocol_core, step_e step);
        case (step)
            Q, K, V: return protocol_core.tile_e;
            QK:      return protocol_core.tile_p;
            AV:      return protocol_core.tile_s;
            OW:      return protocol_core.tile_p;
            F1:      return protocol_core.tile_e;
            F2:      return protocol_core.tile_f;
            default: return 0;
        endcase
    endfunction : protocol_inner_count

    function logic [7:0] protocol_byte(
        int unsigned job_id,
        step_e step,
        int unsigned head_id,
        int unsigned tile_id,
        int unsigned inner_id,
        int unsigned beat_id,
        int unsigned salt
    );
        int signed value;

        value = (job_id * 17 + int'(step) * 13 + head_id * 7 + tile_id * 5 + inner_id * 3 + beat_id + salt) % 31;
        value -= 15;
        return value[7:0];
    endfunction : protocol_byte

    function inp_t protocol_input_payload(
        int unsigned job_id,
        step_e step,
        int unsigned head_id,
        int unsigned tile_id,
        int unsigned inner_id,
        int unsigned beat_id
    );
        logic [7:0] value;

        value = protocol_byte(job_id, step, head_id, tile_id, inner_id, beat_id, 1);
        return inp_t'({($bits(inp_t) / 8){value}});
    endfunction : protocol_input_payload

    function inp_weight_t protocol_weight_payload(
        int unsigned job_id,
        step_e step,
        int unsigned head_id,
        int unsigned tile_id,
        int unsigned inner_id,
        int unsigned beat_id
    );
        logic [7:0] value;

        value = protocol_byte(job_id, step, head_id, tile_id, inner_id, beat_id, 9);
        return inp_weight_t'({($bits(inp_weight_t) / 8){value}});
    endfunction : protocol_weight_payload

    function bias_t protocol_bias_payload(
        int unsigned job_id,
        step_e step,
        int unsigned head_id,
        int unsigned tile_id,
        int unsigned inner_id,
        int unsigned beat_id,
        int unsigned inner_count
    );
        logic [7:0] value;

        if (step inside {QK, AV})
            return '0;

        if (inner_id + 1 < inner_count)
            return '0;

        value = protocol_byte(job_id, step, head_id, tile_id, inner_id, beat_id, 19);
        return bias_t'({($bits(bias_t) / 8){value}});
    endfunction : protocol_bias_payload

endclass : ita_mha8_protocol_random_vsequence

`endif // ITA_MHA8_PROTOCOL_RANDOM_VSEQUENCE_SVH
