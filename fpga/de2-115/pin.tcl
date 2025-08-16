# KEY
set_location_assignment PIN_M23 -to RESETn
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to KEY

# CLOCK
set_location_assignment PIN_Y2 -to CLOCK_50
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to CLOCK_50

# SDRAM
set_location_assignment PIN_AE5 -to SDRAM_CLK
set_location_assignment PIN_W3 -to SDRAM_DQ[0]
set_location_assignment PIN_W2 -to SDRAM_DQ[1]
set_location_assignment PIN_V4 -to SDRAM_DQ[2]
set_location_assignment PIN_W1 -to SDRAM_DQ[3]
set_location_assignment PIN_V3 -to SDRAM_DQ[4]
set_location_assignment PIN_V2 -to SDRAM_DQ[5]
set_location_assignment PIN_V1 -to SDRAM_DQ[6]
set_location_assignment PIN_U3 -to SDRAM_DQ[7]
set_location_assignment PIN_Y3 -to SDRAM_DQ[8]
set_location_assignment PIN_Y4 -to SDRAM_DQ[9]
set_location_assignment PIN_AB1 -to SDRAM_DQ[10]
set_location_assignment PIN_AA3 -to SDRAM_DQ[11]
set_location_assignment PIN_AB2 -to SDRAM_DQ[12]
set_location_assignment PIN_AC1 -to SDRAM_DQ[13]
set_location_assignment PIN_AB3 -to SDRAM_DQ[14]
set_location_assignment PIN_AC2 -to SDRAM_DQ[15]
set_location_assignment PIN_U2 -to SDRAM_DQM[0]
set_location_assignment PIN_W4 -to SDRAM_DQM[1]
set_location_assignment PIN_AA6 -to SDRAM_CKE
set_location_assignment PIN_U6 -to SDRAM_RAS_N
set_location_assignment PIN_V7 -to SDRAM_CAS_N
set_location_assignment PIN_V6 -to SDRAM_WE_N
set_location_assignment PIN_T4 -to SDRAM_CS_N
set_location_assignment PIN_U7 -to SDRAM_BA[0]
set_location_assignment PIN_R4 -to SDRAM_BA[1]
set_location_assignment PIN_Y7 -to SDRAM_ADDR[12]
set_location_assignment PIN_AA5 -to SDRAM_ADDR[11]
set_location_assignment PIN_R5 -to SDRAM_ADDR[10]
set_location_assignment PIN_Y6 -to SDRAM_ADDR[9]
set_location_assignment PIN_Y5 -to SDRAM_ADDR[8]
set_location_assignment PIN_AA7 -to SDRAM_ADDR[7]
set_location_assignment PIN_W7 -to SDRAM_ADDR[6]
set_location_assignment PIN_W8 -to SDRAM_ADDR[5]
set_location_assignment PIN_V5 -to SDRAM_ADDR[4]
set_location_assignment PIN_R6 -to SDRAM_ADDR[0]
set_location_assignment PIN_V8 -to SDRAM_ADDR[1]
set_location_assignment PIN_U8 -to SDRAM_ADDR[2]
set_location_assignment PIN_P1 -to SDRAM_ADDR[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_BA[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_BA[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQM[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQM[1]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_RAS_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_CAS_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_CKE
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_CLK
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_WE_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_CS_N
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[8]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[9]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[10]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[11]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[12]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[13]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[14]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[15]

set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[0]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[1]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[2]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[3]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[4]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[5]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[6]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[7]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[8]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[9]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[10]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[11]
set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_ADDR[12]


#set_location_assignment PIN_M8 -to SDRAM_DQ[16]
#set_location_assignment PIN_L8 -to SDRAM_DQ[17]
#set_location_assignment PIN_P2 -to SDRAM_DQ[18]
#set_location_assignment PIN_N3 -to SDRAM_DQ[19]
#set_location_assignment PIN_N4 -to SDRAM_DQ[20]
#set_location_assignment PIN_M4 -to SDRAM_DQ[21]
#set_location_assignment PIN_M7 -to SDRAM_DQ[22]
#set_location_assignment PIN_L7 -to SDRAM_DQ[23]
#set_location_assignment PIN_U1 -to SDRAM_DQ[31]
#set_location_assignment PIN_U4 -to SDRAM_DQ[30]
#set_location_assignment PIN_T3 -to SDRAM_DQ[29]
#set_location_assignment PIN_R3 -to SDRAM_DQ[28]
#set_location_assignment PIN_R2 -to SDRAM_DQ[27]
#set_location_assignment PIN_R1 -to SDRAM_DQ[26]
#set_location_assignment PIN_R7 -to SDRAM_DQ[25]
#set_location_assignment PIN_U5 -to SDRAM_DQ[24]

#set_location_assignment PIN_K8 -to SDRAM_DQM[2]
#set_location_assignment PIN_N8 -to SDRAM_DQM[3]

#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[16]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[17]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[18]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[19]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[20]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[21]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[22]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[23]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[24]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[25]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[26]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[27]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[28]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[29]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[30]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQ[31]

#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQM[2]
#set_instance_assignment -name IO_STANDARD "3.3-V LVTTL" -to SDRAM_DQM[3]