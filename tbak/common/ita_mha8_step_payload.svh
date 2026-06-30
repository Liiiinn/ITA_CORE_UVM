`ifndef ITA_MHA8_STEP_PAYLOAD_SVH
`define ITA_MHA8_STEP_PAYLOAD_SVH

class ita_mha8_step_payload extends uvm_object;
    `uvm_object_utils(ita_mha8_step_payload)

    step_e step;
    bit    enabled;

    inp_t        input_payload_by_head  [8][$];
    inp_weight_t weight_payload_by_head [8][$];
    bias_t       bias_payload_by_head   [8][$];

    function new(string name = "ita_mha8_step_payload");
        super.new(name);
        step = Idle;
        enabled = 1'b0;
    endfunction : new

    function void clear();
        step = Idle;
        enabled = 1'b0;
        for (int unsigned h = 0; h < 8; h++) begin
            input_payload_by_head[h].delete();
            weight_payload_by_head[h].delete();
            bias_payload_by_head[h].delete();
        end
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

        for (int unsigned h = 0; h < 8; h++) begin
            if (has_any_payload(h) && !has_complete_payload(h)) begin
                `uvm_error("STEP_PAYLOAD",
                    $sformatf("Incomplete payload for step=%s head%0d: input=%0d weight=%0d bias=%0d",
                        step.name(), h,
                        input_payload_by_head[h].size(),
                        weight_payload_by_head[h].size(),
                        bias_payload_by_head[h].size()))
            end
        end
    endfunction : validate_complete
endclass

`endif // ITA_MHA8_STEP_PAYLOAD_SVH