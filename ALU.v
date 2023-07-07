module ALU(
    input   [63:0]    X,
    input   [63:0]    Y,
    input             Is32Bit,
    input   [14:0]    ALUOp,
    output  [63:0]    OUTPUT
);
    reg         [63:0]  RESULT;
    wire signed [63:0]  sX = X;
    wire signed [63:0]  sY = Y;


    always @(*) begin
        case (ALUOp)
            11'h0001:  RESULT = X + Y;  // add
            11'h0002:  RESULT = X - Y;  // sub
            11'h0004:  RESULT = X & Y;  // and
            11'h0008:  RESULT = X | Y;  // or
            11'h0010:  RESULT = X ^ Y;  // xor
            11'h0020:  RESULT = X << Y; // shift left logical
            11'h0040:  RESULT = Is32Bit? {32'b0, X[31:0]} >> Y: X >> Y; // shift right logical
            11'h0080:  RESULT = sX >>> Y;   // shift right arithmetic
            11'h0100:  RESULT = sX[31:0]*sY[31:0];      // mul
            //11'h0200:  RESULT = sX * sY;    // mulh，signed*signed*
            //11'h0400:  RESULT = sX / sY;    // div，X和Y为补码，向0舍入
            //11'h0800:  RESULT = sX % sY;    // rem，X和Y为补码
            11'h1000:  RESULT = sX < sY ? 1 : 0; // set less than (slt)
            11'h2000:  RESULT = X < Y ? 1 : 0;   // set less than (sltu)
            //11'h4000:  RESULT = X == Y;
            default:   RESULT = 0;
        endcase
    end

    assign OUTPUT = Is32Bit? {{32{RESULT[31]}}, RESULT[31:0]}: RESULT[63:0];

endmodule




