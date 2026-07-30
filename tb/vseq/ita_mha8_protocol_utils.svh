function automatic int unsigned ita_mha8_protocol_tile_count(
    ita_mha8_core_item protocol_core,
    step_e step
);
    case (step)
        Q, K, V: return protocol_core.tile_s * protocol_core.tile_p;
        QK:      return protocol_core.tile_s * protocol_core.tile_s;
        AV:      return protocol_core.tile_s * protocol_core.tile_p;
        OW:      return protocol_core.tile_s * protocol_core.tile_e;
        F1:      return protocol_core.tile_s * protocol_core.tile_f;
        F2:      return protocol_core.tile_s * protocol_core.tile_e;
        default: return 0;
    endcase
endfunction : ita_mha8_protocol_tile_count

function automatic int unsigned ita_mha8_protocol_inner_count(
    ita_mha8_core_item protocol_core,
    step_e step
);
    case (step)
        Q, K, V: return protocol_core.tile_e;
        QK:      return protocol_core.tile_p;
        AV:      return protocol_core.tile_s;
        OW:      return protocol_core.tile_p;
        F1:      return protocol_core.tile_e;
        F2:      return protocol_core.tile_f;
        default: return 0;
    endcase
endfunction : ita_mha8_protocol_inner_count

function automatic logic [7:0] ita_mha8_protocol_byte(
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
endfunction : ita_mha8_protocol_byte

function automatic inp_t ita_mha8_protocol_input_payload(
    int unsigned job_id,
    step_e step,
    int unsigned head_id,
    int unsigned tile_id,
    int unsigned inner_id,
    int unsigned beat_id
);
    logic [7:0] value;

    value = ita_mha8_protocol_byte(job_id, step, head_id, tile_id, inner_id, beat_id, 1);
    return inp_t'({($bits(inp_t) / 8){value}});
endfunction : ita_mha8_protocol_input_payload

function automatic inp_weight_t ita_mha8_protocol_weight_payload(
    int unsigned job_id,
    step_e step,
    int unsigned head_id,
    int unsigned tile_id,
    int unsigned inner_id,
    int unsigned beat_id
);
    logic [7:0] value;

    value = ita_mha8_protocol_byte(job_id, step, head_id, tile_id, inner_id, beat_id, 9);
    return inp_weight_t'({($bits(inp_weight_t) / 8){value}});
endfunction : ita_mha8_protocol_weight_payload

function automatic bias_t ita_mha8_protocol_bias_payload(
    int unsigned job_id,
    step_e step,
    int unsigned head_id,
    int unsigned tile_id,
    int unsigned inner_id,
    int unsigned beat_id,
    int unsigned inner_count,
    bit config_toggle_mode
);
    logic [7:0] value;

    if (step inside {QK, AV})
        return '0;
    if (inner_id + 1 < inner_count)
        return '0;
    if (config_toggle_mode && (job_id % 2) == 0)
        return '0;

    value = ita_mha8_protocol_byte(job_id, step, head_id, tile_id, inner_id, beat_id, 19);
    return bias_t'({($bits(bias_t) / 8){value}});
endfunction : ita_mha8_protocol_bias_payload

function automatic void ita_mha8_add_protocol_step(
    ita_mha8_core_item protocol_core,
    step_e step,
    int unsigned job_id,
    bit config_toggle_mode = 1'b0
);
    int unsigned tile_count;
    int unsigned inner_count;
    int unsigned beats_per_segment;

    protocol_core.add_step_to_order(step);
    tile_count = ita_mha8_protocol_tile_count(protocol_core, step);
    inner_count = ita_mha8_protocol_inner_count(protocol_core, step);
    beats_per_segment = M * M / N;

    for (int unsigned tile_id = 0; tile_id < tile_count; tile_id++) begin
        for (int unsigned inner_id = 0; inner_id < inner_count; inner_id++) begin
            ita_mha8_step_payload payload;

            payload = protocol_core.create_schedule_payload(step, tile_id, inner_id);
            for (int unsigned beat_id = 0; beat_id < beats_per_segment; beat_id++) begin
                if (payload.drive_head_streams) begin
                    for (int unsigned head_id = 0; head_id < 8; head_id++) begin
                        payload.input_payload_by_head[head_id].push_back(
                            ita_mha8_protocol_input_payload(job_id, step, head_id, tile_id, inner_id, beat_id));
                        payload.weight_payload_by_head[head_id].push_back(
                            ita_mha8_protocol_weight_payload(job_id, step, head_id, tile_id, inner_id, beat_id));
                        payload.bias_payload_by_head[head_id].push_back(
                            ita_mha8_protocol_bias_payload(
                                job_id, step, head_id, tile_id, inner_id, beat_id,
                                inner_count, config_toggle_mode));
                    end
                end else begin
                    payload.ff_input_payload.push_back(
                        ita_mha8_protocol_input_payload(job_id, step, 0, tile_id, inner_id, beat_id));
                    payload.ff_weight_payload.push_back(
                        ita_mha8_protocol_weight_payload(job_id, step, 0, tile_id, inner_id, beat_id));
                    payload.ff_bias_payload.push_back(
                        ita_mha8_protocol_bias_payload(
                            job_id, step, 0, tile_id, inner_id, beat_id,
                            inner_count, config_toggle_mode));
                end
            end
            payload.validate_complete();
        end
    end
endfunction : ita_mha8_add_protocol_step
