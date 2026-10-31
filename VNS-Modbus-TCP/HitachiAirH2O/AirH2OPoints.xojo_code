#tag Module
Protected Module AirH2OPoints
	#tag Method, Flags = &h1, Description = 4372656174657320657665727920706F696E74206F66207468652061697248324F206D61702E0A
		Protected Function CreatePoints() As ModbusPoint()
		  Return ModbusPointTable.Parse(kPointTable)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 54727565207768656E2074686520676976656E20626974206F66207468652053797374656D20436F6E66696775726174696F6E207265676973746572202861646472657373203130383929206973207365742E0A
		Protected Function HasFeature(configValue As Integer, bit As Integer) As Boolean
		  Return (configValue And Bitwise.ShiftLeft(1, bit)) <> 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 46616C736520666F7220612073656374696F6E2077686F73652066756E6374696F6E206973206E6F7420666974746564206163636F7264696E6720746F207468652053797374656D20436F6E66696775726174696F6E207265676973746572202831303839292E0A
		Protected Function IsSectionFitted(section As String, configValue As Integer) As Boolean
		  Select Case section
		  Case kSectionCircuit1
		    Return HasFeature(configValue, kBitCircuit1Heating) Or HasFeature(configValue, kBitCircuit1Cooling)
		  Case kSectionCircuit2
		    Return HasFeature(configValue, kBitCircuit2Heating) Or HasFeature(configValue, kBitCircuit2Cooling)
		  Case kSectionDHW
		    Return HasFeature(configValue, kBitDHW)
		  Case kSectionPool
		    Return HasFeature(configValue, kBitPool)
		  Else
		    Return True
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 5472756520666F7220636F6D6D616E647320746861742073746F702074686520756E6974206F72206120636972637569743B206368616E676520746865206D6F64653B20737461727420616E74692D6C6567696F6E656C6C61206F72207265706C6163652074686520726F6F6D20746865726D6F737461743A20746865206170702061736B7320666F7220616E20657874726120636F6E6669726D6174696F6E2E0A
		Protected Function IsSensitive(pointName As String) As Boolean
		  Var names() As String = kSensitivePoints.Split(",")
		  Return names.IndexOf(pointName) >= 0
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 5468652073656374696F6E202877696E646F77207061676529206F66206120706F696E743A2073797374656D202F206331202F206332202F20646877202F20706F6F6C202F20737663202F2067773B2066726F6D20697473206E616D65207072656669782E0A
		Protected Function SectionOf(pointName As String) As String
		  Var bareName As String = pointName
		  If bareName.BeginsWith(kControlPrefix) Then bareName = bareName.Middle(kControlPrefix.Length)
		  Var dot As Integer = bareName.IndexOf(".")
		  Var head As String = If(dot < 0, bareName, bareName.Left(dot))
		  Select Case head
		  Case kSectionCircuit1, kSectionCircuit2, kSectionDHW, kSectionPool, kSectionServicing, kSectionGateway
		    Return head
		  Else
		    Return kSectionSystem
		  End Select
		End Function
	#tag EndMethod


	#tag Note, Name = About
		The Hitachi airH2O / Yutaki register map (ATW-MBS-02 gateway, line-up 2016) described as data
		for ModbusPointTable.Parse: see docs/HITACHI_REGISTERS.md for the meaning of each register.
		
		Point names are grouped by prefix, which the windows use to place them:
		unit. system. ctl.unit. ctl.blockMenu ctl.bmsAlarm  -> System
		c1. ctl.c1.  -> Circuit 1        c2. ctl.c2.  -> Circuit 2
		dhw. ctl.dhw. -> DHW             pool. ctl.pool. -> Pool
		svc. -> Servicing                gw. -> Gateway
		Names starting with ctl. are the writable control registers; the others are read-only status.
	#tag EndNote


	#tag Constant, Name = kBitCircuit1Heating, Type = Integer, Dynamic = False, Default = \"0", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kBitCircuit2Heating, Type = Integer, Dynamic = False, Default = \"1", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kBitCircuit1Cooling, Type = Integer, Dynamic = False, Default = \"2", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kBitCircuit2Cooling, Type = Integer, Dynamic = False, Default = \"3", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kBitDHW, Type = Integer, Dynamic = False, Default = \"4", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kBitPool, Type = Integer, Dynamic = False, Default = \"5", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kBitThermostatCircuit1, Type = Integer, Dynamic = False, Default = \"6", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kBitThermostatCircuit2, Type = Integer, Dynamic = False, Default = \"7", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kCentralFull, Type = Integer, Dynamic = False, Default = \"3", Scope = Protected, Description = 43656E7472616C206D6F64652076616C756520726571756972656420666F72204D6F646275732077726974657320746F2062652061636365707465642E0A
	#tag EndConstant

	#tag Constant, Name = kHLinkOK, Type = Integer, Dynamic = False, Default = \"0", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kPointCentralMode, Type = String, Dynamic = False, Default = \"system.central", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kPointConfig, Type = String, Dynamic = False, Default = \"system.config", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kPointHLink, Type = String, Dynamic = False, Default = \"system.hlink", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kPointTable, Type = String, Dynamic = False, Default = \"# Hitachi airH2O / Yutaki - ATW-MBS-02 gateway\x2C line-up 2016 map (docs/HITACHI_REGISTERS.md)\n# name;location;scale;unit;category;label;access;min;max;labels;invalid;decimals\n#\n# --- System status\nunit.run;hr1050;1;;System;Unit;R;;;0\x3DStop|1\x3DRun;65535\nunit.mode;hr1051;1;;System;Unit mode;R;;;0\x3DCool|1\x3DHeat|2\x3DAuto;65535\nsystem.operation;hr1090;1;;System;Operation;R;;;0\x3DOff|1\x3DCool demand off|2\x3DCool thermo off|3\x3DCool thermo on|4\x3DHeat demand off|5\x3DHeat thermo off|6\x3DHeat thermo on|7\x3DDHW off|8\x3DDHW on|9\x3DPool off|10\x3DPool on|11\x3DAlarm;65535\nsystem.outdoor;hr1091:int16;1;\xC2\xB0C;System;Outdoor temperature;R;;;;-127|-67\nsystem.waterInlet;hr1092:int16;1;\xC2\xB0C;System;Water inlet temperature;R;;;;-127|-67\nsystem.waterOutlet;hr1200:int16;1;\xC2\xB0C;System;Water outlet temperature;R;;;;-127|-67\nsystem.unitWaterOutlet;hr1093:int16;1;\xC2\xB0C;System;Unit water outlet temperature;R;;;;-127|-67\nsystem.waterSetting;hr1219:int16;1;\xC2\xB0C;System;Water temperature setting;R;;;;-127|-67\nsystem.alarm;hr1223;1;;System;Alarm number;R;;;0\x3DNo alarm;65535\nsystem.hlink;hr1094;1;;System;H-LINK communication;R;;;0\x3DOK|1\x3DNo communication for 180 s|2\x3DInitialising;65535\nsystem.central;hr1088;1;;System;Central mode;R;;;0\x3DLocal|1\x3DAir|2\x3DWater|3\x3DFull;65535\nsystem.config;hr1089;1;;System;Fitted functions;R;;;b0\x3DCircuit 1 heating|b1\x3DCircuit 2 heating|b2\x3DCircuit 1 cooling|b3\x3DCircuit 2 cooling|b4\x3DDHW|b5\x3DPool|b6\x3DRoom thermostat circuit 1|b7\x3DRoom thermostat circuit 2|b8\x3DWireless setting circuit 1|b9\x3DWireless setting circuit 2|b10\x3DWireless room temperature circuit 1|b11\x3DWireless room temperature circuit 2;65535\nsystem.model;hr1218;1;;System;Unit model;R;;;0\x3DYutaki S|1\x3DYutaki S Combi|2\x3DYutaki S80|3\x3DYutaki M;65535\nsystem.capacity;hr1097;1;kWh;System;Unit capacity;R;;;;65535\nsystem.consumption;hr1098;1;kWh;System;Unit power consumption;R;;;;65535\nsystem.blockMenu;hr1086;1;;System;Controller menu;R;;;0\x3DFree|1\x3DBlocked;65535\nsystem.bmsAlarm;hr1087;1;;System;BMS alarm;R;;;0\x3DNo alarm|1\x3DAlarm;65535\nsystem.softwarePCB;hr1095;1;;System;Software PCB;R;;;;65535\nsystem.softwareLCD;hr1096;1;;System;Software LCD;R;;;;65535\n#\n# --- System control\nctl.unit.run;hr1000;1;;System;Unit on/off;W;0;1;0\x3DStop|1\x3DRun;65535\nctl.unit.mode;hr1001;1;;System;Unit mode setting;W;0;2;0\x3DCool|1\x3DHeat|2\x3DAuto;65535\nctl.blockMenu;hr1032;1;;System;Block controller menu;W;0;1;0\x3DFree|1\x3DBlocked;65535\nctl.bmsAlarm;hr1033;1;;System;BMS alarm signal;W;0;1;0\x3DNo alarm|1\x3DAlarm;65535\n#\n# --- Circuit 1 status\nc1.run;hr1052;1;;Circuit 1;Circuit 1;R;;;0\x3DStop|1\x3DRun;65535\nc1.otcHeat;hr1053;1;;Circuit 1;Heating water law;R;;;0\x3DNone|1\x3DPoints|2\x3DGradient|3\x3DFixed;65535\nc1.otcCool;hr1054;1;;Circuit 1;Cooling water law;R;;;0\x3DNone|1\x3DPoints|2\x3DFixed;65535\nc1.heatFix;hr1055;1;\xC2\xB0C;Circuit 1;Heating water fixed setpoint;R;;;;65535\nc1.coolFix;hr1056;1;\xC2\xB0C;Circuit 1;Cooling water fixed setpoint;R;;;;65535\nc1.eco;hr1057;1;;Circuit 1;Eco mode;R;;;0\x3DECO|1\x3DComfort;65535\nc1.ecoHeat;hr1058;1;\xC2\xB0C;Circuit 1;Heating ECO offset;R;;;;65535\nc1.ecoCool;hr1059;1;\xC2\xB0C;Circuit 1;Cooling ECO offset;R;;;;65535\nc1.roomSetpoint;hr1060;0.1;\xC2\xB0C;Circuit 1;Room setpoint;R;;;;65535\nc1.roomTemp;hr1061;0.1;\xC2\xB0C;Circuit 1;Room temperature;R;;;;65535\nc1.wirelessSetpoint;hr1062;0.1;\xC2\xB0C;Circuit 1;Wireless room setpoint;R;;;;65535\nc1.wirelessTemp;hr1063;0.1;\xC2\xB0C;Circuit 1;Wireless room temperature;R;;;;65535\n#\n# --- Circuit 1 control\nctl.c1.run;hr1002;1;;Circuit 1;Circuit 1 on/off;W;0;1;0\x3DStop|1\x3DRun;65535\nctl.c1.otcHeat;hr1003;1;;Circuit 1;Heating water law setting;W;0;3;0\x3DNone|1\x3DPoints|2\x3DGradient|3\x3DFixed;65535\nctl.c1.otcCool;hr1004;1;;Circuit 1;Cooling water law setting;W;0;2;0\x3DNone|1\x3DPoints|2\x3DFixed;65535\nctl.c1.heatFix;hr1005;1;\xC2\xB0C;Circuit 1;Heating water fixed setpoint setting;W;0;80;;65535\nctl.c1.coolFix;hr1006;1;\xC2\xB0C;Circuit 1;Cooling water fixed setpoint setting;W;0;80;;65535\nctl.c1.eco;hr1007;1;;Circuit 1;Eco mode setting;W;0;1;0\x3DECO|1\x3DComfort;65535\nctl.c1.ecoHeat;hr1008;1;\xC2\xB0C;Circuit 1;Heating ECO offset setting;W;1;10;;65535\nctl.c1.ecoCool;hr1009;1;\xC2\xB0C;Circuit 1;Cooling ECO offset setting;W;1;10;;65535\nctl.c1.thermostat;hr1010;1;;Circuit 1;Modbus thermostat;W;0;1;0\x3DNot available|1\x3DAvailable;65535\nctl.c1.roomSetpoint;hr1011;0.1;\xC2\xB0C;Circuit 1;Room setpoint setting;W;5;35;;65535\nctl.c1.roomTemp;hr1012;0.1;\xC2\xB0C;Circuit 1;Room temperature from Modbus thermostat;W;0;100;;65535\n#\n# --- Circuit 2 status\nc2.run;hr1064;1;;Circuit 2;Circuit 2;R;;;0\x3DStop|1\x3DRun;65535\nc2.otcHeat;hr1065;1;;Circuit 2;Heating water law;R;;;0\x3DNone|1\x3DPoints|2\x3DGradient|3\x3DFixed;65535\nc2.otcCool;hr1066;1;;Circuit 2;Cooling water law;R;;;0\x3DNone|1\x3DPoints|2\x3DFixed;65535\nc2.heatFix;hr1067;1;\xC2\xB0C;Circuit 2;Heating water fixed setpoint;R;;;;65535\nc2.coolFix;hr1068;1;\xC2\xB0C;Circuit 2;Cooling water fixed setpoint;R;;;;65535\nc2.eco;hr1069;1;;Circuit 2;Eco mode;R;;;0\x3DECO|1\x3DComfort;65535\nc2.ecoHeat;hr1070;1;\xC2\xB0C;Circuit 2;Heating ECO offset;R;;;;65535\nc2.ecoCool;hr1071;1;\xC2\xB0C;Circuit 2;Cooling ECO offset;R;;;;65535\nc2.roomSetpoint;hr1072;0.1;\xC2\xB0C;Circuit 2;Room setpoint;R;;;;65535\nc2.roomTemp;hr1073;0.1;\xC2\xB0C;Circuit 2;Room temperature;R;;;;65535\nc2.wirelessSetpoint;hr1074;0.1;\xC2\xB0C;Circuit 2;Wireless room setpoint;R;;;;65535\nc2.wirelessTemp;hr1075;0.1;\xC2\xB0C;Circuit 2;Wireless room temperature;R;;;;65535\nc2.mixingValve;hr1216;1;;Circuit 2;Mixing valve position;R;;;;65535\n#\n# --- Circuit 2 control\nctl.c2.run;hr1013;1;;Circuit 2;Circuit 2 on/off;W;0;1;0\x3DStop|1\x3DRun;65535\nctl.c2.otcHeat;hr1014;1;;Circuit 2;Heating water law setting;W;0;3;0\x3DNone|1\x3DPoints|2\x3DGradient|3\x3DFixed;65535\nctl.c2.otcCool;hr1015;1;;Circuit 2;Cooling water law setting;W;0;2;0\x3DNone|1\x3DPoints|2\x3DFixed;65535\nctl.c2.heatFix;hr1016;1;\xC2\xB0C;Circuit 2;Heating water fixed setpoint setting;W;0;80;;65535\nctl.c2.coolFix;hr1017;1;\xC2\xB0C;Circuit 2;Cooling water fixed setpoint setting;W;0;80;;65535\nctl.c2.eco;hr1018;1;;Circuit 2;Eco mode setting;W;0;1;0\x3DECO|1\x3DComfort;65535\nctl.c2.ecoHeat;hr1019;1;\xC2\xB0C;Circuit 2;Heating ECO offset setting;W;1;10;;65535\nctl.c2.ecoCool;hr1020;1;\xC2\xB0C;Circuit 2;Cooling ECO offset setting;W;1;10;;65535\nctl.c2.thermostat;hr1021;1;;Circuit 2;Modbus thermostat;W;0;1;0\x3DNot available|1\x3DAvailable;65535\nctl.c2.roomSetpoint;hr1022;0.1;\xC2\xB0C;Circuit 2;Room setpoint setting;W;5;35;;65535\nctl.c2.roomTemp;hr1023;0.1;\xC2\xB0C;Circuit 2;Room temperature from Modbus thermostat;R;;;;65535\n#\n# --- Domestic hot water status\ndhw.run;hr1076;1;;DHW;DHW;R;;;0\x3DStop|1\x3DRun;65535\ndhw.setpoint;hr1077;1;\xC2\xB0C;DHW;DHW setpoint;R;;;;65535\ndhw.temp;hr1080:int16;1;\xC2\xB0C;DHW;DHW temperature;R;;;;-127|-67\ndhw.boost;hr1078;1;;DHW;DHW boost;R;;;0\x3DOff|1\x3DOn;65535\ndhw.demand;hr1079;1;;DHW;DHW demand mode;R;;;0\x3DStandard|1\x3DHigh demand;65535\ndhw.legionella;hr1084;1;;DHW;Anti-legionella;R;;;0\x3DStop|1\x3DRun;65535\ndhw.legionellaTemp;hr1085;1;\xC2\xB0C;DHW;Anti-legionella temperature;R;;;;65535\n#\n# --- Domestic hot water control\nctl.dhw.run;hr1024;1;;DHW;DHW on/off;W;0;1;0\x3DStop|1\x3DRun;65535\nctl.dhw.setpoint;hr1025;1;\xC2\xB0C;DHW;DHW setpoint setting;W;0;80;;65535\nctl.dhw.boost;hr1026;1;;DHW;DHW boost request;W;0;1;0\x3DNo request|1\x3DRequest;65535\nctl.dhw.demand;hr1027;1;;DHW;DHW demand mode setting;W;0;1;0\x3DStandard|1\x3DHigh demand;65535\nctl.dhw.legionella;hr1030;1;;DHW;Start anti-legionella;W;0;1;0\x3DStop|1\x3DRun;65535\nctl.dhw.legionellaTemp;hr1031;1;\xC2\xB0C;DHW;Anti-legionella temperature setting;W;0;80;;65535\n#\n# --- Swimming pool\npool.run;hr1081;1;;Pool;Pool;R;;;0\x3DStop|1\x3DRun;65535\npool.setpoint;hr1082;1;\xC2\xB0C;Pool;Pool setpoint;R;;;;65535\npool.temp;hr1083:int16;1;\xC2\xB0C;Pool;Pool temperature;R;;;;-127|-67\nctl.pool.run;hr1028;1;;Pool;Pool on/off;W;0;1;0\x3DStop|1\x3DRun;65535\nctl.pool.setpoint;hr1029;1;\xC2\xB0C;Pool;Pool setpoint setting;W;0;80;;65535\n#\n# --- Servicing (refrigerant circuit)\nsvc.ta2;hr1201:int16;1;\xC2\xB0C;Servicing;Outdoor average temperature (Ta2);R;;;;-127|-67\nsvc.ta;hr1202:int16;1;\xC2\xB0C;Servicing;Second ambient temperature (Ta);R;;;;-127|-67\nsvc.ta3;hr1203:int16;1;\xC2\xB0C;Servicing;Second ambient average temperature (Ta3);R;;;;-127|-67\nsvc.two2;hr1204:int16;1;\xC2\xB0C;Servicing;Water outlet temperature 2 (Two2);R;;;;-127|-67\nsvc.two3;hr1205:int16;1;\xC2\xB0C;Servicing;Water outlet temperature 3 (Two3);R;;;;-127|-67\nsvc.tg;hr1206:int16;1;\xC2\xB0C;Servicing;Gas temperature (Tg);R;;;;-127|-67\nsvc.tl;hr1207:int16;1;\xC2\xB0C;Servicing;Liquid temperature (Tl);R;;;;-127|-67\nsvc.td;hr1208:int16;1;\xC2\xB0C;Servicing;Discharge gas temperature (Td);R;;;;-127|-67\nsvc.te;hr1209:int16;1;\xC2\xB0C;Servicing;Evaporation temperature (Te);R;;;;-127|-67\nsvc.evi;hr1210;1;%;Servicing;Indoor expansion valve (EVI);R;;;;65535\nsvc.evo;hr1211;1;%;Servicing;Outdoor expansion valve (EVO);R;;;;65535\nsvc.frequency;hr1212;1;Hz;Servicing;Compressor frequency (H4);R;;;;65535\nsvc.stopCause;hr1213;1;;Servicing;Cause of stoppage (DI);R;;;;65535\nsvc.current;hr1214;1;A;Servicing;Compressor current (P1);R;;;;65535\nsvc.capacityData;hr1215;1;;Servicing;Capacity data (CD);R;;;;65535\nsvc.defrost;hr1217;1;;Servicing;Defrosting;R;;;0\x3DNo|1\x3DYes;65535\nsvc.flow;hr1220;0.1;m\xC2\xB3/h;Servicing;Water flow;R;;;;65535\nsvc.pump;hr1221;1;%;Servicing;Water pump speed;R;;;;65535\nsvc.status;hr1222;1;;Servicing;Active components;R;;;b0\x3DDefrost|b1\x3DSolar|b2\x3DWater pump 1|b3\x3DWater pump 2|b4\x3DWater pump 3|b5\x3DCompressor|b6\x3DBoiler|b7\x3DDHW heater|b8\x3DSpace heater|b9\x3DSmart function input;65535\nsvc.r134Discharge;hr1224:int16;1;\xC2\xB0C;Servicing;R134a discharge temperature;R;;;;-127|-67\nsvc.r134Suction;hr1225:int16;1;\xC2\xB0C;Servicing;R134a suction temperature;R;;;;-127|-67\nsvc.r134DischargePressure;hr1226;0.01;MPa;Servicing;R134a discharge pressure;R;;;;65535\nsvc.r134SuctionPressure;hr1227;0.01;MPa;Servicing;R134a suction pressure;R;;;;65535\nsvc.r134Frequency;hr1228;1;Hz;Servicing;R134a compressor frequency;R;;;;65535\nsvc.r134Valve;hr1229;1;%;Servicing;R134a indoor expansion valve 2;R;;;;65535\nsvc.r134Current;hr1230;0.1;A;Servicing;R134a compressor current;R;;;;65535\nsvc.r134Retry;hr1231;1;;Servicing;R134a retry code;R;;;;65535\n#\n# --- Gateway\ngw.id0;ir0;1;;Gateway;Hardware id 1;R\ngw.id1;ir1;1;;Gateway;Hardware id 2;R\ngw.id2;ir2;1;;Gateway;Hardware id 3;R\ngw.ip1;hr20;1;;Gateway;IP address byte 1;R\ngw.ip2;hr21;1;;Gateway;IP address byte 2;R\ngw.ip3;hr22;1;;Gateway;IP address byte 3;R\ngw.ip4;hr23;1;;Gateway;IP address byte 4;R\ngw.port;hr24;1;;Gateway;Modbus TCP port;R", Scope = Protected, Description = 5468652061697248324F20706F696E74207461626C653A206F6E6520706F696E7420706572206C696E653B20736565204D6F64627573506F696E745461626C6520666F722074686520636F6C756D6E732E0A
	#tag EndConstant

	#tag Constant, Name = kControlPrefix, Type = String, Dynamic = False, Default = \"ctl.", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSectionCircuit1, Type = String, Dynamic = False, Default = \"c1", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSectionCircuit2, Type = String, Dynamic = False, Default = \"c2", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSectionDHW, Type = String, Dynamic = False, Default = \"dhw", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSectionGateway, Type = String, Dynamic = False, Default = \"gw", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSectionPool, Type = String, Dynamic = False, Default = \"pool", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSectionServicing, Type = String, Dynamic = False, Default = \"svc", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSectionSystem, Type = String, Dynamic = False, Default = \"system", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSensitivePoints, Type = String, Dynamic = False, Default = \"ctl.unit.run\x2Cctl.unit.mode\x2Cctl.c1.run\x2Cctl.c2.run\x2Cctl.c1.thermostat\x2Cctl.c2.thermostat\x2Cctl.c1.roomTemp\x2Cctl.dhw.run\x2Cctl.dhw.legionella\x2Cctl.blockMenu\x2Cctl.bmsAlarm", Scope = Protected
	#tag EndConstant


	#tag ViewBehavior
	#tag EndViewBehavior
End Module
#tag EndModule
