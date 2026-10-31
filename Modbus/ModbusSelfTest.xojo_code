#tag Module
Protected Module ModbusSelfTest
	#tag Method, Flags = &h21
		Private Sub Check(condition As Boolean, label As String)
		  If condition Then
		    mLines.Add(kPass + " " + label)
		  Else
		    mLines.Add(kFail + " " + label)
		    mFailures = mFailures + 1
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 4E756D626572206F66206661696C656420636865636B7320696E20746865206C6173742052756E2E0A
		Protected Function FailureCount() As Integer
		  Return mFailures
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function FromHex(text As String) As MemoryBlock
		  Var bytes As New MemoryBlock(text.Length \ 2)
		  For i As Integer = 0 To bytes.Size - 1
		    bytes.UInt8Value(i) = Integer.FromHex(text.Middle(i * 2, 2))
		  Next
		  Return bytes
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ToHex(bytes As MemoryBlock) As String
		  Var parts() As String
		  For i As Integer = 0 To bytes.Size - 1
		    Var b As Integer = bytes.UInt8Value(i)
		    parts.Add(b.ToHex(2))
		  Next
		  Return String.FromArray(parts, "")
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 52756E7320657665727920636865636B20776974686F757420616E79206465766963652E2052657475726E73206F6E65206C696E652070657220636865636B202850415353202F204641494C2920616E6420612073756D6D617279206C696E652E20557365204661696C757265436F756E7420666F722074686520726573756C742E0A
		Protected Function Run() As String()
		  mLines.RemoveAll
		  mFailures = 0

		  TestConversions
		  TestFrames
		  TestResponses
		  TestPoints
		  TestPointTable
		  TestRTU
		  TestMoreFunctions

		  If mFailures = 0 Then
		    mLines.Add(kAllPassed)
		  Else
		    mLines.Add(mFailures.ToString + " " + kSomeFailed)
		  End If

		  Var report() As String
		  For Each line As String In mLines
		    report.Add(line)
		  Next
		  Return report
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub TestConversions()
		  #Pragma BreakOnExceptions Off
		  Check(ModbusTypes.ToSigned16(65409) = -127, "ToSigned16(0xFF81) = -127")
		  Check(ModbusTypes.ToSigned16(32767) = 32767, "ToSigned16(0x7FFF) = 32767")

		  Var words() As UInt16 = ModbusTypes.EncodeValue(-2, ModbusTypes.eDataType.Signed16)
		  Check(words(0) = 65534, "Encode Signed16 -2 = 0xFFFE")

		  ' IEEE 754 1.0 = 3F80 0000 laid out in the four word orders
		  words = ModbusTypes.EncodeValue(1.0, ModbusTypes.eDataType.Float32, ModbusTypes.eWordOrder.ABCD)
		  Check(words(0) = &h3F80 And words(1) = 0, "Float32 1.0 ABCD = 3F80 0000")
		  words = ModbusTypes.EncodeValue(1.0, ModbusTypes.eDataType.Float32, ModbusTypes.eWordOrder.CDAB)
		  Check(words(0) = 0 And words(1) = &h3F80, "Float32 1.0 CDAB = 0000 3F80")
		  words = ModbusTypes.EncodeValue(1.0, ModbusTypes.eDataType.Float32, ModbusTypes.eWordOrder.BADC)
		  Check(words(0) = &h803F And words(1) = 0, "Float32 1.0 BADC = 803F 0000")
		  words = ModbusTypes.EncodeValue(1.0, ModbusTypes.eDataType.Float32, ModbusTypes.eWordOrder.DCBA)
		  Check(words(0) = 0 And words(1) = &h803F, "Float32 1.0 DCBA = 0000 803F")

		  ' Round trips in every word order
		  For orderIndex As Integer = 0 To 3
		    Var order As ModbusTypes.eWordOrder = ModbusTypes.eWordOrder(orderIndex)
		    Var suffix As String = " order " + orderIndex.ToString
		    words = ModbusTypes.EncodeValue(-123456789, ModbusTypes.eDataType.Signed32, order)
		    Check(ModbusTypes.DecodeValue(words, 0, ModbusTypes.eDataType.Signed32, order) = -123456789, "Signed32 round trip" + suffix)
		    words = ModbusTypes.EncodeValue(4000000000.0, ModbusTypes.eDataType.Unsigned32, order)
		    Check(ModbusTypes.DecodeValue(words, 0, ModbusTypes.eDataType.Unsigned32, order) = 4000000000.0, "Unsigned32 round trip" + suffix)
		    words = ModbusTypes.EncodeValue(-1234.5678, ModbusTypes.eDataType.Float64, order)
		    Check(ModbusTypes.DecodeValue(words, 0, ModbusTypes.eDataType.Float64, order) = -1234.5678, "Float64 round trip" + suffix)
		  Next

		  Var rejected As Boolean
		  Try
		    words = ModbusTypes.EncodeValue(70000, ModbusTypes.eDataType.Unsigned16)
		  Catch err As InvalidArgumentException
		    rejected = True
		  End Try
		  #Pragma BreakOnExceptions Off
		  Check(rejected, "Unsigned16 70000 is rejected")

		  Var zero As Double
		  rejected = False
		  Try
		    words = ModbusTypes.EncodeValue(zero / zero, ModbusTypes.eDataType.Signed16)
		  Catch err As InvalidArgumentException
		    rejected = True
		  End Try
		  #Pragma BreakOnExceptions Off
		  Check(rejected, "NaN is rejected")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub TestFrames()
		  #Pragma BreakOnExceptions Off
		  Var request As New ModbusRequest(ModbusTypes.eFunction.ReadHoldingRegisters, 1080, 2)
		  Check(ToHex(request.BuildFrame(7, 1)) = "000700000006010304380002", "FC03 frame")

		  Var oneRegister() As UInt16
		  oneRegister.Add(50)
		  request = New ModbusRequest(ModbusTypes.eFunction.WriteSingleRegister, 1025, oneRegister)
		  Check(ToHex(request.BuildFrame(1, 1)) = "000100000006010604010032", "FC06 frame")

		  Var coil() As UInt16
		  coil.Add(1)
		  request = New ModbusRequest(ModbusTypes.eFunction.WriteSingleCoil, 0, coil)
		  Check(ToHex(request.BuildFrame(1, 1)) = "00010000000601050000FF00", "FC05 frame")

		  Var registers() As UInt16
		  registers.Add(&h1234)
		  registers.Add(&hABCD)
		  request = New ModbusRequest(ModbusTypes.eFunction.WriteMultipleRegisters, 10, registers)
		  Check(ToHex(request.BuildFrame(1, 1)) = "00010000000B0110000A0002041234ABCD", "FC16 frame")

		  Var coils() As UInt16
		  Var pattern() As Integer = Array(1, 0, 1, 0, 1)
		  For Each bit As Integer In pattern
		    coils.Add(bit)
		  Next
		  request = New ModbusRequest(ModbusTypes.eFunction.WriteMultipleCoils, 3, coils)
		  Check(ToHex(request.BuildFrame(1, 1)) = "000100000008010F000300050115", "FC15 frame")

		  Var toWrite() As UInt16
		  toWrite.Add(11)
		  toWrite.Add(22)
		  toWrite.Add(33)
		  request = New ModbusRequest(299, 4, 300, toWrite)
		  Check(ToHex(request.BuildFrame(1, 1)) = "0001000000110117012B0004012C000306000B00160021", "FC23 frame")
		  Check(request.ParseResponse(FromHex("17080000000B00160021")) And request.Values.Count = 4 And request.Values(3) = 33, "FC23 response: 4 registers read after the write")

		  request = New ModbusRequest(ModbusTypes.eFunction.ReadInputRegisters, 0, 3)
		  request.UnitID = 255
		  Check(ToHex(request.BuildFrame(2, 1)) = "000200000006FF0400000003", "Request UnitID overrides the client's")

		  Var rejected As Boolean
		  Try
		    request = New ModbusRequest(ModbusTypes.eFunction.ReadHoldingRegisters, 0, 126)
		  Catch err As InvalidArgumentException
		    rejected = True
		  End Try
		  Check(rejected, "FC03 with 126 registers is rejected")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub TestRTU()
		  ' Reference frames computed independently (Python, CRC-16/MODBUS).
		  Var probe As MemoryBlock = FromHex("01030000000A")
		  Check(ModbusTypes.CRC16(probe, probe.Size) = &hCDC5, "CRC16 of 01 03 00 00 00 0A = C5 CD")
		  
		  Var request As New ModbusRequest(ModbusTypes.eFunction.ReadHoldingRegisters, 0, 10)
		  Check(ToHex(request.BuildRTUFrame(1)) = "01030000000AC5CD", "RTU frame FC03")
		  
		  Var oneRegister() As UInt16
		  oneRegister.Add(3)
		  request = New ModbusRequest(ModbusTypes.eFunction.WriteSingleRegister, 1, oneRegister)
		  request.UnitID = 17
		  Check(ToHex(request.BuildRTUFrame(1)) = "1106000100039A9B" And request.SentUnitID = 17, "RTU frame FC06 unit 17")
		  
		  Var toWrite() As UInt16
		  toWrite.Add(11)
		  toWrite.Add(22)
		  toWrite.Add(33)
		  request = New ModbusRequest(299, 4, 300, toWrite)
		  Check(ToHex(request.BuildRTUFrame(1)) = "0117012B0004012C000306000B00160021125B", "RTU frame FC23")
		  
		  Check(ModbusTypes.RTUResponseLength(FromHex("0103")) = 0, "RTU length: more bytes needed")
		  Check(ModbusTypes.RTUResponseLength(FromHex("010304")) = 9, "RTU length: FC03 with 4 data bytes = 9")
		  Check(ModbusTypes.RTUResponseLength(FromHex("0183")) = 5, "RTU length: exception = 5")
		  Check(ModbusTypes.RTUResponseLength(FromHex("0106")) = 8, "RTU length: FC06 echo = 8")
		  Check(ModbusTypes.RTUResponseLength(FromHex("011708")) = 13, "RTU length: FC23 with 8 data bytes = 13")
		  
		  Var answer As MemoryBlock = FromHex("010304002CFF81BA6A")
		  Var answerCRC As Integer = answer.UInt8Value(7) + answer.UInt8Value(8) * 256
		  Check(ModbusTypes.CRC16(answer, answer.Size - 2) = answerCRC, "RTU answer CRC checks")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub TestMoreFunctions()
		  ' FC 22, 08 / 00, 17, 43 / 14: frames and answers computed independently (Python).
		  Var request As ModbusRequest = ModbusRequest.MaskWrite(400, &hF0F0, &h0F0F)
		  Check(ToHex(request.BuildFrame(1, 1)) = "00010000000801160190F0F00F0F", "FC22 frame")
		  Check(ToHex(request.BuildRTUFrame(1)) = "01160190F0F00F0F410D", "FC22 RTU frame")
		  Check(request.ParseResponse(FromHex("160190F0F00F0F")), "FC22 echo accepted")
		  
		  request = ModbusRequest.ReturnQueryData(&hA537)
		  Check(ToHex(request.BuildFrame(1, 1)) = "00010000000601080000A537", "FC08 frame")
		  Check(ToHex(request.BuildRTUFrame(1)) = "01080000A537DA8D", "FC08 RTU frame")
		  Check(request.ParseResponse(FromHex("080000A537")), "FC08 loopback accepted")
		  request = ModbusRequest.ReturnQueryData(&hA537)
		  Call request.ParseResponse(FromHex("080000A538"))
		  Check(request.ErrorCode = ModbusTypes.eError.InvalidResponse, "FC08 different data is rejected")
		  
		  request = ModbusRequest.ReportServerID
		  Check(ToHex(request.BuildFrame(1, 1)) = "0001000000020111", "FC17 frame")
		  Check(ToHex(request.BuildRTUFrame(1)) = "0111C02C", "FC17 RTU frame")
		  Check(request.ParseResponse(FromHex("1108564E532D53494DFF")) And request.ResponseBytes.Size = 8 _
		  And request.ResponseBytes.UInt8Value(7) = &hFF, "FC17 answer: 8 bytes, running")
		  
		  request = ModbusRequest.ReadDeviceIdentification(1, 0)
		  Check(ToHex(request.BuildFrame(1, 1)) = "000100000005012B0E0100", "FC43 frame")
		  Check(ToHex(request.BuildRTUFrame(1)) = "012B0E01007077", "FC43 RTU frame")
		  Var answer As String = "2B0E0182000003000A566572796E69636553570107564E532D53494D0205312E312E30"
		  Check(request.ParseResponse(FromHex(answer)) And request.DeviceObjects.KeyCount = 3 _
		  And request.DeviceObjects.Value(0).StringValue = "VeryniceSW" And request.DeviceObjects.Value(2).StringValue = "1.1.0" _
		  And Not request.MoreFollows, "FC43 answer: 3 objects parsed")
		  
		  Check(ModbusTypes.RTUResponseLength(FromHex("01" + answer)) = 38, "RTU length: FC43 parsed from its objects = 38")
		  Check(ModbusTypes.RTUResponseLength(FromHex("011108")) = 13, "RTU length: FC17 with 8 bytes = 13")
		  Check(ModbusTypes.RTUResponseLength(FromHex("0116")) = 10, "RTU length: FC22 = 10")
		  Check(ModbusTypes.RTUResponseLength(FromHex("0108"), 5) = 8, "RTU length: FC08 = request size")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub TestPointTable()
		  #Pragma BreakOnExceptions Off
		  Var table As String = "# comment" + EndOfLine.UNIX _
		  + "dhw.temp;hr1080:int16;1;°C;DHW;DHW temperature;R;;;;-127|-67" + EndOfLine.UNIX _
		  + "" + EndOfLine.UNIX _
		  + "dhw.setpoint;hr1025;1;°C;DHW;DHW setpoint;W;30;60;;;0" + EndOfLine.UNIX _
		  + "room;hr1061;0.1;°C;Circuit 1;Room;R;;;" + EndOfLine.UNIX _
		  + "run;hr1076;1;;DHW;Run state;R;;;0=Stop|1=Run" + EndOfLine.UNIX _
		  + "status;hr1222;1;;Servicing;Status;R;;;b0=Defrost|b5=Compressor"
		  Var points() As ModbusPoint = ModbusPointTable.Parse(table)
		  Check(points.Count = 5, "Table: 5 points; comment and empty line skipped")
		  If points.Count <> 5 Then Return
		  
		  Check(points(0).DataType = ModbusTypes.eDataType.Signed16 And points(0).InvalidValues.Count = 2 And points(0).Category = "DHW", "Table: type; invalid values; category")
		  Check(points(1).Writable And points(1).MinValue = 30 And points(1).MaxValue = 60 And points(1).Decimals = 0, "Table: writable with range and decimals")
		  Check(points(2).Scale = 0.1, "Table: scale with a dot whatever the locale")
		  
		  Var block() As UInt16
		  block.Add(1)
		  points(3).Update(block, 0)
		  Check(points(3).DisplayText = "Run", "Table: enum labels")
		  block(0) = &h21
		  points(4).Update(block, 0)
		  Check(points(4).DisplayText = "Defrost" + ModbusPoint.kBitSeparator + "Compressor", "Table: bit labels")
		  
		  Var rejected As Boolean
		  Try
		    points = ModbusPointTable.Parse("bad;zz1")
		  Catch err As InvalidArgumentException
		    rejected = True
		  End Try
		  Check(rejected, "Table: bad location is rejected")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub TestPoints()
		  #Pragma BreakOnExceptions Off
		  Var p As New ModbusPoint("dhw", "hr1080:int16", 1.0, "°C")
		  Check(p.Area = ModbusTypes.eArea.HoldingRegister And p.Address = 1080 And p.DataType = ModbusTypes.eDataType.Signed16, "Parse hr1080:int16")

		  p = New ModbusPoint("energy", "ir30:float32:cdab")
		  Check(p.Area = ModbusTypes.eArea.InputRegister And p.RegisterCount = 2 And p.WordOrder = ModbusTypes.eWordOrder.CDAB, "Parse ir30:float32:cdab")

		  p = New ModbusPoint("dhwFitted", "hr1089.4")
		  Check(p.BitIndex = 4 And p.DataType = ModbusTypes.eDataType.Bit, "Parse hr1089.4")
		  Var block() As UInt16
		  block.Add(&h00D1)
		  p.Update(block, 0)
		  Check(p.Value = 1, "Bit 4 of 0x00D1 is set")

		  p = New ModbusPoint("coil", "co7")
		  Check(p.Area = ModbusTypes.eArea.Coil And p.Address = 7, "Parse co7")

		  Var rejected As Boolean
		  Try
		    p = New ModbusPoint("bad", "xx12")
		  Catch err As InvalidArgumentException
		    rejected = True
		  End Try
		  Check(rejected, "Location xx12 is rejected")

		  rejected = False
		  Try
		    p = New ModbusPoint("bad", "hr65535:float32")
		  Catch err As InvalidArgumentException
		    rejected = True
		  End Try
		  #Pragma BreakOnExceptions Off
		  Check(rejected, "hr65535:float32 (past the address space) is rejected")

		  rejected = False
		  Try
		    p = New ModbusPoint("bad", "co5:int32")
		  Catch err As InvalidArgumentException
		    rejected = True
		  End Try
		  #Pragma BreakOnExceptions Off
		  Check(rejected, "co5:int32 (wide type on a coil) is rejected")

		  ' Enum label, sentinel value and scaling
		  p = New ModbusPoint("run", "hr1076")
		  p.AddEnumLabel(0, "Stop")
		  p.AddEnumLabel(1, "Run")
		  block(0) = 1
		  p.Update(block, 0)
		  Check(p.DisplayText = "Run", "Enum label")

		  p = New ModbusPoint("pool", "hr1083:int16", 1.0, "°C")
		  p.InvalidValues.Add(-127)
		  block(0) = &hFF81
		  p.Update(block, 0)
		  Check(Not p.IsValid And p.DisplayText = ModbusPoint.kTextInvalid, "Sentinel -127 is shown as not available")

		  p = New ModbusPoint("room", "hr1061", 0.1, "°C")
		  block(0) = 235
		  p.Update(block, 0)
		  Check(Abs(p.Value - 23.5) < 0.0001, "Scale 0.1: 235 -> 23.5")

		  ' Write range check
		  p = New ModbusPoint("setpoint", "hr1025", 1.0, "°C")
		  p.Writable = True
		  p.MinValue = 30
		  p.MaxValue = 60
		  Var words() As UInt16 = p.EncodeForWrite(50)
		  Check(words(0) = 50, "EncodeForWrite 50")
		  rejected = False
		  Try
		    words = p.EncodeForWrite(75)
		  Catch err As InvalidArgumentException
		    rejected = True
		  End Try
		  Check(rejected, "EncodeForWrite 75 is out of range")
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub TestResponses()
		  Var request As New ModbusRequest(ModbusTypes.eFunction.ReadHoldingRegisters, 1080, 2)
		  Check(request.ParseResponse(FromHex("0304002CFF81")), "FC03 response accepted")
		  Check(request.Values.Count = 2 And request.Values(0) = 44, "FC03 first register = 44")
		  Check(request.ValueAt(1, ModbusTypes.eDataType.Signed16) = -127, "FC03 second register as Signed16 = -127")

		  request = New ModbusRequest(ModbusTypes.eFunction.ReadCoils, 0, 5)
		  Check(request.ParseResponse(FromHex("010115")), "FC01 response accepted")
		  Check(request.Values.Count = 5 And request.Values(0) = 1 And request.Values(1) = 0 And request.Values(4) = 1, "FC01 bits 1 0 1 0 1")

		  request = New ModbusRequest(ModbusTypes.eFunction.ReadCoils, 0, 5)
		  Call request.ParseResponse(FromHex("8101"))
		  Check(request.ErrorCode = ModbusTypes.eError.ExceptionResponse And request.ExceptionCode = 1, "Exception 1 detected")

		  request = New ModbusRequest(ModbusTypes.eFunction.ReadHoldingRegisters, 0, 2)
		  Call request.ParseResponse(FromHex("03020001"))
		  Check(request.ErrorCode = ModbusTypes.eError.InvalidResponse, "Short byte count is rejected")

		  request = New ModbusRequest(ModbusTypes.eFunction.ReadHoldingRegisters, 0, 1)
		  Call request.ParseResponse(FromHex("04020001"))
		  Check(request.ErrorCode = ModbusTypes.eError.InvalidResponse, "Wrong function code is rejected")

		  Var written() As UInt16
		  written.Add(50)
		  request = New ModbusRequest(ModbusTypes.eFunction.WriteSingleRegister, 1025, written)
		  Check(request.ParseResponse(FromHex("0604010032")), "FC06 echo accepted")
		  request = New ModbusRequest(ModbusTypes.eFunction.WriteSingleRegister, 1025, written)
		  Call request.ParseResponse(FromHex("0604010033"))
		  Check(request.ErrorCode = ModbusTypes.eError.InvalidResponse, "FC06 echo with another value is rejected")
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mFailures As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLines() As String
	#tag EndProperty


	#tag Constant, Name = kAllPassed, Type = String, Dynamic = False, Default = \"All checks passed.", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kFail, Type = String, Dynamic = False, Default = \"FAIL", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kPass, Type = String, Dynamic = False, Default = \"PASS", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSomeFailed, Type = String, Dynamic = False, Default = \"check(s) failed.", Scope = Protected
	#tag EndConstant


	#tag ViewBehavior
	#tag EndViewBehavior
End Module
#tag EndModule
