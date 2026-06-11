`ifndef ITA_STREAM_ITEM_SVH
`define ITA_STREAM_ITEM_SVH

typedef enum int unsigned {
    ITA_STREAM_HEAD_INPUT,
    ITA_STREAM_HEAD_WEIGHT,
    ITA_STREAM_HEAD_BIAS,
    ITA_STREAM_HEAD_OUTPUT,
    ITA_STREAM_SUM_OUTPUT,
    ITA_STREAM_FF_INPUT,
    ITA_STREAM_FF_WEIGHT,
    ITA_STREAM_FF_BIAS,
    ITA_STREAM_FF_OUTPUT
} ita_stream_kind_e;

class ita_stream_item extends uvm_sequence_item;
    `uvm_object_utils(ita_stream_item)

    ita_stream_kind_e kind;
    int unsigned      head_id;
    inp_t             inp;
    inp_weight_t      weight;
    bias_t            bias;
    requant_oup_t     oup;
    step_e            step;

    function new(string name = "ita_stream_item");
        super.new(name);
        kind = ITA_STREAM_HEAD_INPUT;
        head_id = 0;
        inp = '0;
        weight = '0;
        bias = '0;
        oup = '0;
        step = Idle;
    endfunction : new

endclass : ita_stream_item

`endif // ITA_STREAM_ITEM_SVH
