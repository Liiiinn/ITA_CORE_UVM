`ifndef ITA_MHA8_STEP_PAYLOAD_SVH
`define ITA_MHA8_STEP_PAYLOAD_SVH

class ita_mha8_step_payload extends uvm_object;
    `uvm_object_utils(ita_mha8_step_payload)

    step_e step;
    bit    enabled;
    int unsigned tile_id;
    int unsigned inner_tile_id;
    bit drive_head_streams;
    bit expect_head_output;
    bit expect_sum_output;
    bit drive_ff_streams;
    bit expect_ff_output;

    inp_t        input_payload_by_head  [8][$];
    inp_weight_t weight_payload_by_head [8][$];
    bias_t       bias_payload_by_head   [8][$];
    inp_t        ff_input_payload       [$];
    inp_weight_t ff_weight_payload      [$];
    bias_t       ff_bias_payload        [$];


    function new(string name = "ita_mha8_step_payload");
        super.new(name);
        clear();        
    endfunction : new

    function void clear();
        step = Idle;
        enabled = 1'b0;
        tile_id = 0;
        inner_tile_id = 0;
        drive_head_streams = 1'b0;
        expect_head_output = 1'b0;
        expect_sum_output  = 1'b0;
        drive_ff_streams   = 1'b0;
        expect_ff_output   = 1'b0;

        for (int unsigned h = 0; h < 8; h++) begin
            input_payload_by_head[h].delete();
            weight_payload_by_head[h].delete();
            bias_payload_by_head[h].delete();
        end

        ff_input_payload.delete();
        ff_weight_payload.delete();
        ff_bias_payload.delete();
    endfunction : clear

    function bit has_complete_payload(int unsigned h);
        if (h >= 8)
            return 1'b0;
        return input_payload_by_head[h].size() != 0
            && weight_payload_by_head[h].size() != 0
            && bias_payload_by_head[h].size() != 0;
    endfunction : has_complete_payload

    function bit has_any_payload(int unsigned h);
        if (h >= 8)
            return 1'b0;
        return input_payload_by_head[h].size() != 0
            || weight_payload_by_head[h].size() != 0
            || bias_payload_by_head[h].size() != 0;
    endfunction : has_any_payload

    function void validate_complete();
        if (!enabled)
            return;

        if (drive_head_streams) begin
            for (int unsigned h = 0; h < 8; h++) begin
                if (has_any_payload(h) && !has_complete_payload(h)) begin
                    `uvm_error("STEP PAYLOAD",
                        $sformatf("Incomplete head payload for step=%s head%0d: input=%0d weight=%0d bias=%0d",
                            step.name(), h,
                            input_payload_by_head[h].size(),
                            weight_payload_by_head[h].size(),
                            bias_payload_by_head[h].size()))
                end
            end
        end

        if (drive_ff_streams) begin
            if (ff_input_payload.size() == 0 ||
                ff_weight_payload.size() == 0 ||
                ff_bias_payload.size() == 0) begin
                `uvm_error("STEP PAYLOAD",
                    $sformatf("Incomplete FF payload for step=%s: input=%0d weight=%0d bias=%0d",
                        step.name(),
                        ff_input_payload.size(),
                        ff_weight_payload.size(),
                        ff_bias_payload.size()))
            end
        end
    endfunction : validate_complete

    function void configure_for_step(step_e step_value);
        clear();
        step = step_value;
        enabled = 1'b1;

        case (step)
            Q, K, V, QK, AV, OW: begin
                drive_head_streams = 1'b1;
                expect_head_output = 1'b1;
            end
            F1, F2: begin
                drive_ff_streams = 1'b1;
                expect_ff_output = 1'b1;
            end
            default:
                `uvm_fatal("STEP PAYLOAD", $sformatf("No default behavior for step=%s", step.name()))
        endcase

        if (step == OW)
            expect_sum_output = 1'b1;
    endfunction
endclass

`endif // ITA_MHA8_STEP_PAYLOAD_SVH