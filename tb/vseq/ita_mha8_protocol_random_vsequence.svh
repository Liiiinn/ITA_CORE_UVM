`ifndef ITA_MHA8_PROTOCOL_RANDOM_VSEQUENCE_SVH
`define ITA_MHA8_PROTOCOL_RANDOM_VSEQUENCE_SVH

class ita_mha8_protocol_random_vsequence extends ita_mha8_vsequence;
    `uvm_object_utils(ita_mha8_protocol_random_vsequence)
    `uvm_declare_p_sequencer(ita_mha8_vsequencer)

    function new(string name = "ita_mha8_protocol_random_vsequence");
        super.new(name);
    endfunction : new

    virtual task body();
        if (scenario == null)
            `uvm_fatal("PROTOCOL_RAND", "Scenario config is not set")

        for (int unsigned job_id = 0; job_id < scenario.num_jobs; job_id++) begin
            build_protocol_core(job_id, core);

            `uvm_info("PROTOCOL_RAND",
                $sformatf("Starting protocol job=%0d projection=%s activation=%s tile_s/e/p/f=%0d/%0d/%0d/%0d",
                    job_id,
                    scenario.protocol_projection,
                    core.activation.name(),
                    core.tile_s,
                    core.tile_e,
                    core.tile_p,
                    core.tile_f),
                UVM_LOW)

            execute_core_job(core);
            wait_protocol_start_gap();
        end
    endtask : body

    task wait_protocol_start_gap();
        int unsigned gap_cycles;

        if (scenario.protocol_start_gap_max == 0)
            return;

        gap_cycles = $urandom_range(scenario.protocol_start_gap_max, 0);
        repeat (gap_cycles) begin
            @(posedge p_sequencer.vif.clk_i);
        end
    endtask : wait_protocol_start_gap

    task build_protocol_core(int unsigned job_id, output ita_mha8_core_item protocol_core);
        string selected_projection;
        bit include_attention;
        bit include_ff;

        protocol_core = ita_mha8_core_item::type_id::create($sformatf("protocol_core_%0d", job_id));
        if (scenario.protocol_config_toggle) begin
            protocol_core.tile_s = config_toggle_tile(job_id, 0);
            protocol_core.tile_e = config_toggle_tile(job_id, 1);
            protocol_core.tile_p = config_toggle_tile(job_id, 2);
            protocol_core.tile_f = config_toggle_tile(job_id, 3);
            case (job_id % 3)
                0: protocol_core.activation = Identity;
                1: protocol_core.activation = Relu;
                default: protocol_core.activation = Gelu;
            endcase
        end else begin
            protocol_core.tile_s = tile_t'($urandom_range(scenario.protocol_tile_max, scenario.protocol_tile_min));
            protocol_core.tile_e = tile_t'($urandom_range(scenario.protocol_tile_max, scenario.protocol_tile_min));
            protocol_core.tile_p = tile_t'($urandom_range(scenario.protocol_tile_max, scenario.protocol_tile_min));
            protocol_core.tile_f = tile_t'($urandom_range(scenario.protocol_tile_max, scenario.protocol_tile_min));
            protocol_core.activation = random_activation();
        end
        protocol_core.clear_requant_config();
        if (scenario.protocol_config_toggle)
            configure_toggle_requant(protocol_core, job_id);

        selected_projection = scenario.protocol_projection.toupper();
        include_attention = 1'b0;
        include_ff = 1'b0;
        if (selected_projection == "RANDOM") begin
            case ($urandom_range(2))
                0: include_attention = 1'b1;
                1: include_ff = 1'b1;
                default: begin
                    include_attention = 1'b1;
                    include_ff = 1'b1;
                end
            endcase
        end else if (selected_projection == "ATTN") begin
            include_attention = 1'b1;
        end else if (selected_projection == "FF") begin
            include_ff = 1'b1;
        end else begin
            include_attention = 1'b1;
            include_ff = 1'b1;
        end

        if (include_attention) begin
            protocol_core.layer = Attention;
            ita_mha8_add_protocol_step(protocol_core, Q, job_id, scenario.protocol_config_toggle);
            ita_mha8_add_protocol_step(protocol_core, K, job_id, scenario.protocol_config_toggle);
            ita_mha8_add_protocol_step(protocol_core, V, job_id, scenario.protocol_config_toggle);
            ita_mha8_add_protocol_step(protocol_core, QK, job_id, scenario.protocol_config_toggle);
            ita_mha8_add_protocol_step(protocol_core, AV, job_id, scenario.protocol_config_toggle);
            ita_mha8_add_protocol_step(protocol_core, OW, job_id, scenario.protocol_config_toggle);
        end

        if (include_ff) begin
            if (!include_attention)
                protocol_core.layer = Feedforward;
            ita_mha8_add_protocol_step(protocol_core, F1, job_id, scenario.protocol_config_toggle);
            ita_mha8_add_protocol_step(protocol_core, F2, job_id, scenario.protocol_config_toggle);
        end

        if (scenario.protocol_config_toggle) begin
            `uvm_info("PROTOCOL_CFG_TOGGLE",
                $sformatf("job=%0d tile_s/e/p/f=%0d/%0d/%0d/%0d activation=%s requant_profile=%0d bias_mode=%s",
                    job_id,
                    protocol_core.tile_s,
                    protocol_core.tile_e,
                    protocol_core.tile_p,
                    protocol_core.tile_f,
                    protocol_core.activation.name(),
                    job_id % 2,
                    ((job_id % 2) == 0) ? "zero" : "nonzero"),
                UVM_LOW)
        end

    endtask : build_protocol_core

    function tile_t config_toggle_tile(int unsigned job_id, int unsigned dimension);
        int unsigned schedule[4][4] = '{
            '{1, 2, 1, 2},
            '{2, 1, 2, 1},
            '{1, 1, 2, 2},
            '{2, 2, 1, 1}
        };

        return tile_t'(schedule[dimension % 4][job_id % 4]);
    endfunction : config_toggle_tile

    function void configure_toggle_requant(
        ita_mha8_core_item protocol_core,
        int unsigned job_id
    );
        requant_const_t mult_value;
        requant_const_t shift_value;
        requant_t add_value;

        mult_value = requant_const_t'((job_id % 2) == 0 ? 1 : 3);
        shift_value = requant_const_t'((job_id % 2) == 0 ? 0 : 1);
        add_value = requant_t'((job_id % 2) == 0 ? 0 : 1);
        protocol_core.has_requant_config = 1'b1;

        for (int unsigned index = 0; index < N_REQUANT_CONSTS; index++) begin
            protocol_core.ff_eps_mult[index] = mult_value;
            protocol_core.ff_right_shift[index] = shift_value;
            protocol_core.ff_add[index] = add_value;
            for (int unsigned h = 0; h < 8; h++) begin
                protocol_core.head_eps_mult[h][index] = mult_value;
                protocol_core.head_right_shift[h][index] = shift_value;
                protocol_core.head_add[h][index] = add_value;
            end
        end

        protocol_core.sum_eps_mult = mult_value;
        protocol_core.sum_right_shift = shift_value;
        protocol_core.sum_add = add_value;
        protocol_core.activation_requant_mult = mult_value;
        protocol_core.activation_requant_shift = shift_value;
        protocol_core.activation_requant_add = add_value;
        protocol_core.gelu_b = gelu_const_t'(2 + (job_id % 2));
        protocol_core.gelu_c = gelu_const_t'(1 + (job_id % 2));
    endfunction : configure_toggle_requant

    function activation_e random_activation();
        case ($urandom_range(2))
            0: return Identity;
            1: return Relu;
            default: return Gelu;
        endcase
    endfunction : random_activation

endclass : ita_mha8_protocol_random_vsequence

`endif // ITA_MHA8_PROTOCOL_RANDOM_VSEQUENCE_SVH
