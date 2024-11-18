`default_nettype none
module top (
  input  logic hz100, reset,
  input  logic [20:0] pb,
  output logic [7:0] left, right,
         ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0,
  output logic red, green, blue,
  output logic [7:0] txdata,
  input  logic [7:0] rxdata,
  output logic txclk, rxclk,
  input  logic txready, rxready
);
    mod5fsmEn fsm (
        .clk(pb[3]),
        .reset(pb[2]),
        .en(pb[1]),
        .x(pb[0]),
        .mod(right[3:0])
    );
endmodule

module finalModuloDesign (
    input logic clk,           // Clock input (manual or hardware)
    input logic reset,         // Reset signal
    input logic Start,         // Start signal
    input logic [7:0] dataIn,  // 8-bit parallel input data
    output logic [3:0] mod,    // Modulo output
    output logic Done,         // Done signal
    output logic [7:0] Q,      // Shift register state (debugging)
    output logic serialOut,    // Serial output from the shift register (debugging)
    output logic [3:0] state   // State of the controller (debugging)
);

    // Internal signals
    logic Load, Enable;

    // Instantiate the 8-bit Shift Register
    loadShiftEn8 shiftRegister (
        .clk(clk),
        .reset(reset),
        .dataIn(dataIn),
        .load(Load),
        .en(Enable),
        .Q(Q),
        .serialOut(serialOut)
    );

    // Instantiate the Modulo-5 State Machine
    mod5fsmEn mod5 (
        .clk(clk),
        .reset(reset),
        .en(Enable),
        .x(serialOut),  // Serial input from the shift register
        .mod(mod)
    );

    // Instantiate the Timer/Controller
    timerLoadShiftDone controller (
        .clk(clk),
        .reset(reset),
        .Start(Start),
        .Load(Load),
        .Enable(Enable),
        .Done(Done),
        .Q(state)  // Controller state for debugging
    );

endmodule


module mod5fsmEn (
    input logic clk,
    input logic reset,
    input logic en,
    input logic x,
    output logic [3:0] mod
);
    typedef enum logic [2:0] {mod0 = 3'b000, mod1 = 3'b001, mod2 = 3'b010, mod3 = 3'b011, mod4 = 3'b100} state_t;
    state_t Q, nextQ;
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            Q <= mod0;
        else if (en)
            Q <= nextQ;
    end
    always_comb begin
        case (Q)
            mod0: nextQ = (x == 1) ? mod1 : mod0;
            mod1: nextQ = (x == 1) ? mod3 : mod2;
            mod2: nextQ = (x == 1) ? mod0 : mod4;
            mod3: nextQ = (x == 1) ? mod2 : mod1;
            mod4: nextQ = (x == 1) ? mod4 : mod3;
            default: nextQ = mod0;
        endcase
    end
    assign mod = {1'b0, Q}; 
endmodule

module loadShiftEn8 (
    input logic clk,
    input logic reset,
    input logic [7:0] dataIn,
    input logic load,
    input logic en,
    output logic [7:0] Q,
    output logic serialOut
);
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            Q <= 8'b0;
        else if (load)
            Q <= dataIn;
        else if (en)
            Q <= {Q[6:0], 1'b0};
    end
    assign serialOut = Q[7];
endmodule

module timerLoadShiftDone (
    input logic clk,
    input logic reset,
    input logic Start,
    output logic Load,
    output logic Enable,
    output logic Done,
    output logic [3:0] Q
);
    typedef enum logic [3:0] {IDLE = 4'd0, LOAD = 4'd1, SHIFT = 4'd2, DONE = 4'd9} state_t;
    state_t state, nextState;
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= nextState;
    end
    always_comb begin
        case (state)
            IDLE: nextState = Start ? LOAD : IDLE;
            LOAD: nextState = SHIFT;
            SHIFT: nextState = (Q == 4'd8) ? DONE : SHIFT;
            DONE: nextState = IDLE;
            default: nextState = IDLE;
        endcase
    end
    always_comb begin
        Load = (state == LOAD);
        Enable = (state == SHIFT);
        Done = (state == DONE);
    end
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            Q <= 4'd0;
        else if (Enable)
            Q <= Q + 1;
    end
endmodule
