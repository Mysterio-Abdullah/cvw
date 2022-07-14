///////////////////////////////////////////
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: special case selection
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// MIT LICENSE
// Permission is hereby granted, free of charge, to any person obtaining a copy of this 
// software and associated documentation files (the "Software"), to deal in the Software 
// without restriction, including without limitation the rights to use, copy, modify, merge, 
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
// to whom the Software is furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all copies or 
//   substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
//   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
//   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
//   OR OTHER DEALINGS IN THE SOFTWARE.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module specialcase(
    input logic                 Xs,        // input signs
    input logic  [`NF:0]        Xm, Ym, Zm, // input mantissas
    input logic                 XNaN, YNaN, ZNaN,    // inputs are NaN
    input logic  [2:0]          Frm,       // rounding mode 000 = rount to nearest, ties to even   001 = round twords zero  010 = round down  011 = round up  100 = round to nearest, ties to max magnitude
    input logic  [`FMTBITS-1:0] OutFmt,       // output format
    input logic                 InfIn,
    input logic                 NaNIn,
    input logic                 XInf, YInf,
    input logic                 XZero,
    input logic                 IntZero,
    input logic                 IntToFp,
    input logic                 Int64,
    input logic                 Signed,
    input logic                 CvtOp,
    input logic                 DivOp,
    input logic                 FmaOp,
    input logic                 Plus1,
    input logic                 DivByZero,
    input logic  [`NE:0]        CvtCe,    // the calculated expoent
    input logic                 Ws,  // the res's sign
    input logic                 IntInvalid, Invalid, Overflow,  // flags
    input logic                 CvtResUf,
    input logic  [`NE-1:0]      Re,          // Res exponent
    input logic  [`NE+1:0]      FullRe,          // Res exponent
    input logic  [`NF-1:0]      Rf,         // Res fraction
    input logic  [`XLEN+1:0]    CvtNegRes,     // the negation of the result
    output logic [`FLEN-1:0]    PostProcRes,     // final res
    output logic [`XLEN-1:0]    FCvtIntRes     // final res
);
    logic [`FLEN-1:0]   XNaNRes, YNaNRes, ZNaNRes, InvalidRes, OfRes, UfRes, NormRes; // possible results
    logic OfResMax;
    logic [`XLEN-1:0]       OfIntRes;   // the overflow result for integer output
    logic KillRes;
    logic SelOfRes;


    // does the overflow result output the maximum normalized floating point number
    //                output infinity if the input is infinity
    assign OfResMax = (~InfIn|(IntToFp&CvtOp))&~DivByZero&((Frm[1:0]==2'b01) | (Frm[1:0]==2'b10&~Ws) | (Frm[1:0]==2'b11&Ws));

    if (`FPSIZES == 1) begin

        //NaN res selection depending on standard
        if(`IEEE754) begin
            assign XNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Xm[`NF-2:0]};
            assign YNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Ym[`NF-2:0]};
            assign ZNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Zm[`NF-2:0]};
            assign InvalidRes = {1'b0, {`NE{1'b1}}, 1'b1, {`NF-1{1'b0}}};
        end else begin
            assign InvalidRes = {1'b0, {`NE{1'b1}}, 1'b1, {`NF-1{1'b0}}};
        end

        assign OfRes =  OfResMax ? {Ws, {`NE-1{1'b1}}, 1'b0, {`NF{1'b1}}} : {Ws, {`NE{1'b1}}, {`NF{1'b0}}};
        assign UfRes = {Ws, {`FLEN-2{1'b0}}, Plus1&Frm[1]&~(DivOp&YInf)};
        assign NormRes = {Ws, Re, Rf};

    end else if (`FPSIZES == 2) begin //will the format conversion in killprod work in other conversions?
        if(`IEEE754) begin
            assign XNaNRes = OutFmt ? {1'b0, {`NE{1'b1}}, 1'b1, Xm[`NF-2:0]} : {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, Xm[`NF-2:`NF-`NF1]};
            assign YNaNRes = OutFmt ? {1'b0, {`NE{1'b1}}, 1'b1, Ym[`NF-2:0]} : {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, Ym[`NF-2:`NF-`NF1]};
            assign ZNaNRes = OutFmt ? {1'b0, {`NE{1'b1}}, 1'b1, Zm[`NF-2:0]} : {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, Zm[`NF-2:`NF-`NF1]};
            assign InvalidRes = OutFmt ? {1'b0, {`NE{1'b1}}, 1'b1, {`NF-1{1'b0}}} : {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, (`NF1-1)'(0)};
        end else begin 
            assign InvalidRes = OutFmt ? {1'b0, {`NE{1'b1}}, 1'b1, {`NF-1{1'b0}}} : {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, (`NF1-1)'(0)};
        end
        
        assign OfRes =  OutFmt ? OfResMax ? {Ws, {`NE-1{1'b1}}, 1'b0, {`NF{1'b1}}} : {Ws, {`NE{1'b1}}, {`NF{1'b0}}} :
                               OfResMax ? {{`FLEN-`LEN1{1'b1}}, Ws, {`NE1-1{1'b1}}, 1'b0, {`NF1{1'b1}}} : {{`FLEN-`LEN1{1'b1}}, Ws, {`NE1{1'b1}}, (`NF1)'(0)};
        assign UfRes = OutFmt ? {Ws, (`FLEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)} : {{`FLEN-`LEN1{1'b1}}, Ws, (`LEN1-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
        assign NormRes = OutFmt ? {Ws, Re, Rf} : {{`FLEN-`LEN1{1'b1}}, Ws, Re[`NE1-1:0], Rf[`NF-1:`NF-`NF1]};

    end else if (`FPSIZES == 3) begin
        always_comb
            case (OutFmt)
                `FMT: begin  
                    if(`IEEE754) begin
                        XNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Xm[`NF-2:0]};
                        YNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Ym[`NF-2:0]};
                        ZNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Zm[`NF-2:0]};
                        InvalidRes = {1'b0, {`NE{1'b1}}, 1'b1, {`NF-1{1'b0}}};
                    end else begin 
                        InvalidRes = {1'b0, {`NE{1'b1}}, 1'b1, {`NF-1{1'b0}}};
                    end
                    
                    OfRes = OfResMax ? {Ws, {`NE-1{1'b1}}, 1'b0, {`NF{1'b1}}} : {Ws, {`NE{1'b1}}, {`NF{1'b0}}};
                    UfRes = {Ws, (`FLEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                    NormRes = {Ws, Re, Rf};
                end
                `FMT1: begin  
                    if(`IEEE754) begin
                        XNaNRes = {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, Xm[`NF-2:`NF-`NF1]};
                        YNaNRes = {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, Ym[`NF-2:`NF-`NF1]};
                        ZNaNRes = {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, Zm[`NF-2:`NF-`NF1]};
                        InvalidRes = {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, (`NF1-1)'(0)};
                    end else begin 
                        InvalidRes = {{`FLEN-`LEN1{1'b1}}, 1'b0, {`NE1{1'b1}}, 1'b1, (`NF1-1)'(0)};
                    end
                    OfRes = OfResMax ? {{`FLEN-`LEN1{1'b1}}, Ws, {`NE1-1{1'b1}}, 1'b0, {`NF1{1'b1}}} : {{`FLEN-`LEN1{1'b1}}, Ws, {`NE1{1'b1}}, (`NF1)'(0)};
                    UfRes = {{`FLEN-`LEN1{1'b1}}, Ws, (`LEN1-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                    NormRes = {{`FLEN-`LEN1{1'b1}}, Ws, Re[`NE1-1:0], Rf[`NF-1:`NF-`NF1]};
                end
                `FMT2: begin  
                    if(`IEEE754) begin
                        XNaNRes = {{`FLEN-`LEN2{1'b1}}, 1'b0, {`NE2{1'b1}}, 1'b1, Xm[`NF-2:`NF-`NF2]};
                        YNaNRes = {{`FLEN-`LEN2{1'b1}}, 1'b0, {`NE2{1'b1}}, 1'b1, Ym[`NF-2:`NF-`NF2]};
                        ZNaNRes = {{`FLEN-`LEN2{1'b1}}, 1'b0, {`NE2{1'b1}}, 1'b1, Zm[`NF-2:`NF-`NF2]};
                        InvalidRes = {{`FLEN-`LEN2{1'b1}}, 1'b0, {`NE2{1'b1}}, 1'b1, (`NF2-1)'(0)};
                    end else begin 
                        InvalidRes = {{`FLEN-`LEN2{1'b1}}, 1'b0, {`NE2{1'b1}}, 1'b1, (`NF2-1)'(0)};
                    end
                    
                    OfRes = OfResMax ? {{`FLEN-`LEN2{1'b1}}, Ws, {`NE2-1{1'b1}}, 1'b0, {`NF2{1'b1}}} : {{`FLEN-`LEN2{1'b1}}, Ws, {`NE2{1'b1}}, (`NF2)'(0)};
                    UfRes = {{`FLEN-`LEN2{1'b1}}, Ws, (`LEN2-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                    NormRes = {{`FLEN-`LEN2{1'b1}}, Ws, Re[`NE2-1:0], Rf[`NF-1:`NF-`NF2]};
                end
                default: begin
                    if(`IEEE754) begin
                        XNaNRes = (`FLEN)'(0);
                        YNaNRes = (`FLEN)'(0);
                        ZNaNRes = (`FLEN)'(0);
                        InvalidRes = (`FLEN)'(0);
                    end else begin 
                        InvalidRes = (`FLEN)'(0);
                    end
                    OfRes = (`FLEN)'(0);
                    UfRes = (`FLEN)'(0);
                    NormRes = (`FLEN)'(0);
                end
            endcase

    end else if (`FPSIZES == 4) begin 
        always_comb
            case (OutFmt)
                2'h3: begin  
                    if(`IEEE754) begin
                        XNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Xm[`NF-2:0]};
                        YNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Ym[`NF-2:0]};
                        ZNaNRes = {1'b0, {`NE{1'b1}}, 1'b1, Zm[`NF-2:0]};
                        InvalidRes = {1'b0, {`NE{1'b1}}, 1'b1, {`NF-1{1'b0}}};
                    end else begin 
                        InvalidRes = {1'b0, {`NE{1'b1}}, 1'b1, {`NF-1{1'b0}}};
                    end
                    
                    OfRes = OfResMax ? {Ws, {`NE-1{1'b1}}, 1'b0, {`NF{1'b1}}} : {Ws, {`NE{1'b1}}, {`NF{1'b0}}};
                    UfRes = {Ws, (`FLEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                    NormRes = {Ws, Re, Rf};
                end
                2'h1: begin  
                    if(`IEEE754) begin
                        XNaNRes = {{`FLEN-`D_LEN{1'b1}}, 1'b0, {`D_NE{1'b1}}, 1'b1, Xm[`NF-2:`NF-`D_NF]};
                        YNaNRes = {{`FLEN-`D_LEN{1'b1}}, 1'b0, {`D_NE{1'b1}}, 1'b1, Ym[`NF-2:`NF-`D_NF]};
                        ZNaNRes = {{`FLEN-`D_LEN{1'b1}}, 1'b0, {`D_NE{1'b1}}, 1'b1, Zm[`NF-2:`NF-`D_NF]};
                        InvalidRes = {{`FLEN-`D_LEN{1'b1}}, 1'b0, {`D_NE{1'b1}}, 1'b1, (`D_NF-1)'(0)};
                    end else begin 
                        InvalidRes = {{`FLEN-`D_LEN{1'b1}}, 1'b0, {`D_NE{1'b1}}, 1'b1, (`D_NF-1)'(0)};
                    end
                    OfRes = OfResMax ? {{`FLEN-`D_LEN{1'b1}}, Ws, {`D_NE-1{1'b1}}, 1'b0, {`D_NF{1'b1}}} : {{`FLEN-`D_LEN{1'b1}}, Ws, {`D_NE{1'b1}}, (`D_NF)'(0)};
                    UfRes = {{`FLEN-`D_LEN{1'b1}}, Ws, (`D_LEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                    NormRes = {{`FLEN-`D_LEN{1'b1}}, Ws, Re[`D_NE-1:0], Rf[`NF-1:`NF-`D_NF]};
                end
                2'h0: begin  
                    if(`IEEE754) begin
                        XNaNRes = {{`FLEN-`S_LEN{1'b1}}, 1'b0, {`S_NE{1'b1}}, 1'b1, Xm[`NF-2:`NF-`S_NF]};
                        YNaNRes = {{`FLEN-`S_LEN{1'b1}}, 1'b0, {`S_NE{1'b1}}, 1'b1, Ym[`NF-2:`NF-`S_NF]};
                        ZNaNRes = {{`FLEN-`S_LEN{1'b1}}, 1'b0, {`S_NE{1'b1}}, 1'b1, Zm[`NF-2:`NF-`S_NF]};
                        InvalidRes = {{`FLEN-`S_LEN{1'b1}}, 1'b0, {`S_NE{1'b1}}, 1'b1, (`S_NF-1)'(0)};
                    end else begin 
                        InvalidRes = {{`FLEN-`S_LEN{1'b1}}, 1'b0, {`S_NE{1'b1}}, 1'b1, (`S_NF-1)'(0)};
                    end
                    
                    OfRes = OfResMax ? {{`FLEN-`S_LEN{1'b1}}, Ws, {`S_NE-1{1'b1}}, 1'b0, {`S_NF{1'b1}}} : {{`FLEN-`S_LEN{1'b1}}, Ws, {`S_NE{1'b1}}, (`S_NF)'(0)};
                    UfRes = {{`FLEN-`S_LEN{1'b1}}, Ws, (`S_LEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                    NormRes = {{`FLEN-`S_LEN{1'b1}}, Ws, Re[`S_NE-1:0], Rf[`NF-1:`NF-`S_NF]};
                end
                2'h2: begin  
                    if(`IEEE754) begin
                        XNaNRes = {{`FLEN-`H_LEN{1'b1}}, 1'b0, {`H_NE{1'b1}}, 1'b1, Xm[`NF-2:`NF-`H_NF]};
                        YNaNRes = {{`FLEN-`H_LEN{1'b1}}, 1'b0, {`H_NE{1'b1}}, 1'b1, Ym[`NF-2:`NF-`H_NF]};
                        ZNaNRes = {{`FLEN-`H_LEN{1'b1}}, 1'b0, {`H_NE{1'b1}}, 1'b1, Zm[`NF-2:`NF-`H_NF]};
                        InvalidRes = {{`FLEN-`H_LEN{1'b1}}, 1'b0, {`H_NE{1'b1}}, 1'b1, (`H_NF-1)'(0)};
                    end else begin 
                        InvalidRes = {{`FLEN-`H_LEN{1'b1}}, 1'b0, {`H_NE{1'b1}}, 1'b1, (`H_NF-1)'(0)};
                    end
                    
                    OfRes = OfResMax ? {{`FLEN-`H_LEN{1'b1}}, Ws, {`H_NE-1{1'b1}}, 1'b0, {`H_NF{1'b1}}} : {{`FLEN-`H_LEN{1'b1}}, Ws, {`H_NE{1'b1}}, (`H_NF)'(0)};      
	            // zero is exact fi dividing by infinity so don't add 1
                    UfRes = {{`FLEN-`H_LEN{1'b1}}, Ws, (`H_LEN-2)'(0), Plus1&Frm[1]&~(DivOp&YInf)};
                    NormRes = {{`FLEN-`H_LEN{1'b1}}, Ws, Re[`H_NE-1:0], Rf[`NF-1:`NF-`H_NF]};
                end
            endcase

    end

    



    // determine if you shoould kill the res - Cvt
    //      - do so if the res underflows, is zero (the exp doesnt calculate correctly). or the integer input is 0
    //      - dont set to zero if fp input is zero but not using the fp input
    //      - dont set to zero if int input is zero but not using the int input
    assign KillRes = CvtOp ? (CvtResUf|(XZero&~IntToFp)|(IntZero&IntToFp)) : FullRe[`NE+1] | (((YInf&~XInf)|XZero)&DivOp);//Underflow & ~ResDenorm & (Re!=1);
    assign SelOfRes = Overflow|DivByZero|(InfIn&~(YInf&DivOp));
    // output infinity with result sign if divide by zero
    if(`IEEE754) begin
        assign PostProcRes = XNaN&~(IntToFp&CvtOp) ? XNaNRes :
                         YNaN&~CvtOp ? YNaNRes :
                         ZNaN&FmaOp ? ZNaNRes :
                         Invalid ? InvalidRes : 
                         SelOfRes ? OfRes :
                         KillRes ? UfRes :  
                         NormRes;
    end else begin
        assign PostProcRes = NaNIn|Invalid ? InvalidRes :
                         SelOfRes ? OfRes :
                         KillRes ? UfRes :  
                         NormRes;
    end

    ///////////////////////////////////////////////////////////////////////////////////////
    //
    //      |||||||||||   |||     |||   |||||||||||||
    //          |||       ||||||  |||        |||
    //          |||       ||| ||| |||        |||
    //          |||       |||  ||||||        |||
    //      |||||||||||   |||     |||        |||
    //
    ///////////////////////////////////////////////////////////////////////////////////////        

    // *** probably can optimize the negation
    // select the overflow integer res
    //      - negitive infinity and out of range negitive input
    //                 |  int  |  long  |
    //          signed | -2^31 | -2^63  |
    //        unsigned |   0   |    0   |
    //
    //      - positive infinity and out of range positive input and NaNs
    //                 |   int  |  long  |
    //          signed | 2^31-1 | 2^63-1 |
    //        unsigned | 2^32-1 | 2^64-1 |
    //
    //      other: 32 bit unsinged res should be sign extended as if it were a signed number
    assign OfIntRes = Signed ? Xs&~XNaN ? Int64 ? {1'b1, {`XLEN-1{1'b0}}} : {{`XLEN-32{1'b1}}, 1'b1, {31{1'b0}}} : // signed negitive
                                              Int64 ? {1'b0, {`XLEN-1{1'b1}}} : {{`XLEN-32{1'b0}}, 1'b0, {31{1'b1}}} : // signed positive
                               Xs&~XNaN ? {`XLEN{1'b0}} : // unsigned negitive
                                              {`XLEN{1'b1}};// unsigned positive


    // select the integer output
    //      - if the input is invalid (out of bounds NaN or Inf) then output overflow res
    //      - if the input underflows
    //          - if rounding and signed opperation and negitive input, output -1
    //          - otherwise output a rounded 0
    //      - otherwise output the normal res (trmined and sign extended if nessisary)
    assign FCvtIntRes = IntInvalid ?  OfIntRes :
			            CvtCe[`NE] ? Xs&Signed&Plus1 ? {{`XLEN{1'b1}}} : {{`XLEN-1{1'b0}}, Plus1} : //CalcExp has to come after invalid ***swap to actual mux at some point??
                        Int64 ? CvtNegRes[`XLEN-1:0] : {{`XLEN-32{CvtNegRes[31]}}, CvtNegRes[31:0]};
endmodule