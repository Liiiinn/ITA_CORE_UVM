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

    int unsigned job_id;

    function void do_copy(uvm_object rhs);
        ita_stream_item other;

        super.do_copy(rhs);
        if (!$cast(other, rhs)) begin
            `uvm_fatal("ITA_COPY", "Wrong transaction type")
        end

        job_id        = other.job_id;
        kind          = other.kind;
        head_id       = other.head_id;
        tile_id       = other.tile_id;
        inner_tile_id = other.inner_tile_id;
        beat_id        = other.beat_id;
        is_lockstep    = other.is_lockstep;
        inp            = other.inp;
        weight         = other.weight;
        bias           = other.bias;
        oup            = other.oup;
        step           = other.step;
    endfunction : do_copy

    function new(string name = "ita_stream_item");
        super.new(name);
        job_id = 0;
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
