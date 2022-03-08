/* Name: Raad Khan
   Student ID: 26751157
   Purpose: The link io controller at the top-level */

module io_controller_top import typedefs::*;(
        input logic clk,
        input logic wd_rst,
        input logic app_activate, app_hibernate,
        timer_sleep,
        charger_charge,
        afe_ok, a2d_ok, dsp_ok, blem_ok,

        output logic idle_o, activate_o, hibernate_o, sleep_o, charge_o,
        stream_eeg_o, process_eeg_o, interpret_eeg_o,
        build_ble_cmd_o, publish_ble_cmd_o
    );

    logic[8:0] opcode;
    output_t io_pipe_req;

    opcode_encoder oe(app_activate, app_hibernate,
                      timer_sleep,
                      charger_charge,
                      afe_ok, a2d_ok, dsp_ok, blem_ok,

                      opcode
                     );

    io_controller ic(clk,
                     wd_rst,
                     opcode,

                     io_pipe_req
                    );

    io_pipe_req_decoder iprd(io_pipe_req,
                             idle_o, activate_o, hibernate_o, sleep_o, charge_o,
                             stream_eeg_o, process_eeg_o, interpret_eeg_o,
                             build_ble_cmd_o, publish_ble_cmd_o
                            );
endmodule
