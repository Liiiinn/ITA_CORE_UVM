`ifndef ITA_STREAM_COMMON_SVH
`define ITA_STREAM_COMMON_SVH

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
// TODO Stage 3-5: reuse this enum and one ita_stream_agent implementation for input, weight, bias, and output.

`endif // ITA_STREAM_COMMON_SVH
