`ifndef ITA_STREAM_ITEM_SVH
`define ITA_STREAM_ITEM_SVH

class ita_stream_item extends uvm_sequence_item;
    `uvm_object_utils(ita_stream_item)

    ita_stream_kind_e kind;
    int unsigned      head_id;
    int unsigned      tile_id;
    int unsigned      inner_tile_id;
    int unsigned      beat_id;
    bit               is_lockstep;
    inp_t             inp;
    inp_weight_t      weight;
    bias_t            bias;
    requant_oup_t     oup;
    step_e            step;

    function new(string name = "ita_stream_item");
        super.new(name);
        kind = ITA_STREAM_HEAD_INPUT;
        head_id = 0;
        tile_id = 0;
        inner_tile_id = 0;
        beat_id = 0;
        is_lockstep = 1'b0;
        inp = '0;
        weight = '0;
        bias = '0;
        oup = '0;
        step = Idle;
    endfunction : new

endclass : ita_stream_item

`endif // ITA_STREAM_ITEM_SVH
