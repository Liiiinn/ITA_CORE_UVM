`ifndef ITA_MHA8_CORE_ITEM_SVH
`define ITA_MHA8_CORE_ITEM_SVH

class ita_mha8_core_item extends uvm_sequence_item;
    `uvm_object_utils(ita_mha8_core_item)

    layer_e      layer;
    activation_e activation;
    tile_t       tile_s;
    tile_t       tile_e;
    tile_t       tile_p;
    tile_t       tile_f;
    // Stage 6: choose testcase intent fields before splitting into ctrl and stream items.
    int unsigned target_head_id;

    inp_t        input_payload[$];
    inp_weight_t weight_payload[$];
    bias_t       bias_payload[$];
    // Stage 6: define head0 payload ordering before adding random or full-head payloads.

    string       expected_path;
    string       actual_path;
    string       compare_path;
    // TODO Stage 10: pass these paths to logger and post-simulation Python compare flow.

    function new(string name = "ita_mha8_core_item");
        super.new(name);
        layer = Attention;
        activation = Identity;
        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        target_head_id = 0;
        expected_path = "";
        actual_path = "";
        compare_path = "";
        // TODO Stage 9: seed a small manually checkable Linear transaction in the derived test.
    endfunction : new

    function void set_linear_directed_head0;
        layer = Linear;
        activation = Identity;

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;

        target_head_id = 0;

        input_payload.delete();
        weight_payload.delete();
        bias_payload.delete();

        input_payload.push_back(2);
        for (int unsigned i = 0; i < N_WRITE_EN; i++) begin
            weight_payload.push_back(2);
        end
        bias_payload.push_back(4);
    endfunction : set_linear_directed_head0

    function void set_linear_head0_multibeat();
        layer = Linear;
        activation = Identity;

        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        target_head_id = 0;

        input_payload.delete();
        weight_payload.delete();
        bias_payload.delete();

        // weight controller 需要先收满 N_WRITE_EN，默认就是 64。
        for (int unsigned i = 0; i < N_WRITE_EN; i++) begin
            weight_payload.push_back('0);
        end

        // 先做 1 个 compute beat。
        input_payload.push_back('0);
        bias_payload.push_back('0);

        expected_path = "logger/ita_mha8_expected.csv";
        actual_path   = "logger/ita_mha8_output.csv";
        compare_path  = "logger/ita_mha8_compare.txt";
    endfunction
endclass : ita_mha8_core_item

`endif // ITA_MHA8_CORE_ITEM_SVH
