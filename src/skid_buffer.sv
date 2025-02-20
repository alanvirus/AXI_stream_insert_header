////////////////////////////////////////////////////////////////////////////////
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology
//
////////////////////////////////////////////////////////////////////////////////
// Copyright (C) 2019-2025, Gisselquist Technology, LLC
// Modified by: Lesi Wei, THU
// This file is part of the AXI_stream_insert_header project.
//
// The AXI_stream_insert_header project contains free software and gateware, licensed under the
// Apache License, Version 2.0 (the "License").  You may not use this project,
// or this file, except in compliance with the License.  You may obtain a copy
// of the License at
//	http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
// License for the specific language governing permissions and limitations
// under the License.
//
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
module skidbuffer #(
    parameter	DW = 8
) (
    input	wire			i_clk, i_reset,
    input	wire			i_valid,
    output	wire			o_ready,
    input	wire	[DW-1:0]	i_data,
    output	wire			o_valid,
    input	wire			i_ready,
    output	reg	[DW-1:0]	o_data
);
    reg			r_valid;
    reg	[DW-1:0]	r_data;

    always_ff @(posedge i_clk)
    if (~i_reset)
        r_valid <= 0;
    else if ((i_valid && o_ready) && (o_valid && !i_ready)) 
        r_valid <= 1;
    else if (i_ready)
        r_valid <= 0;
    
    always_ff @(posedge i_clk)
    if (o_ready)
        r_data <= i_data;

    assign o_ready = !r_valid;

    assign	o_valid = i_reset && (i_valid || r_valid);
   
    always_comb begin
        if (r_valid)
            o_data = r_data;
        else 
            o_data = i_data;
    end
endmodule