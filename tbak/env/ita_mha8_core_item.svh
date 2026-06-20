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
    inp_t        input_payload[$];
    inp_weight_t weight_payload[$];
    bias_t       bias_payload[$];
    string       expected_path;
    string       actual_path;
    string       compare_path;

    function new(string name = "ita_mha8_core_item");
        super.new(name);
        layer = Linear;
        activation = Identity;
        tile_s = 1;
        tile_e = 1;
        tile_p = 1;
        tile_f = 1;
        expected_path = "";
        actual_path = "";
        compare_path = "";
    endfunction : new

endclass : ita_mha8_core_item

`endif // ITA_MHA8_CORE_ITEM_SVH
