`ifndef ITA_STREAM_COMMON_SVH
`define ITA_STREAM_COMMON_SVH

typedef enum int unsigned {
    ITA_STREAM_HEAD_INPUT,
    ITA_STREAM_HEAD_WEIGHT,
    ITA_STREAM_HEAD_BIAS,
    ITA_STREAM_HEAD_OUTPUT
} ita_stream_kind_e;

typedef enum int unsigned {
    ITA_STREAM_SOURCE,
    ITA_STREAM_SINK
} ita_stream_direction_e;

`endif // ITA_STREAM_COMMON_SVH
