#tag Class
Protected Class LiveTestClient
Inherits ModbusTCPClient
	#tag Event
		Sub Disconnected(reason As ModbusTypes.eError)
		  If reason <> ModbusTypes.eError.None Then mReport.Add(kFail + " " + ModbusTypes.ErrorText(reason) + " " + LastErrorMessage)
		End Sub
	#tag EndEvent

	#tag Event
		Sub RequestCompleted(request As ModbusRequest)
		  Var parts() As String = request.Tag.StringValue.Split(kTagSeparator)
		  Var label As String = parts(0)
		  Var ok As Boolean = True

		  If parts.Count > 1 Then
		    If parts(1) = kExpectFloat Then
		      ok = Abs(request.ValueAt(0, ModbusTypes.eDataType.Float32, ModbusTypes.eWordOrder.CDAB) - kFloatValue) < 0.0001
		    Else
		      Var expected() As String = parts(1).Split(",")
		      ok = (expected.Count = request.Values.Count)
		      If ok Then
		        For i As Integer = 0 To expected.LastIndex
		          If expected(i).ToInteger <> request.Values(i) Then ok = False
		        Next
		      End If
		    End If
		  End If

		  Var milliseconds As Integer = Round(request.ResponseTimeMS)
		  Var timing As String = milliseconds.ToString + " ms"
		  mReport.Add(If(ok, kPass, kFail) + " " + label + " (" + timing + ")")
		  If Not ok Then mFailures = mFailures + 1
		  mDone = mDone + 1
		End Sub
	#tag EndEvent

	#tag Event
		Sub RequestFailed(request As ModbusRequest)
		  Var parts() As String = request.Tag.StringValue.Split(kTagSeparator)
		  mReport.Add(kFail + " " + parts(0) + ": " + request.ErrorMessage)
		  mFailures = mFailures + 1
		  mDone = mDone + 1
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0
		Function Failures() As Integer
		  Return mFailures
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Finished() As Boolean
		  Return mExpected > 0 And mDone >= mExpected
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Report() As String()
		  Return mReport
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Start()
		  ' Every request is queued at once: the client sends them one by one, in this order, so
		  ' each read checks the write just before it. Tag = label|expected values.
		  WriteSingleCoil(0, True, Nil, "FC05 write coil 0")
		  ReadCoils(0, 1, Nil, "FC01 read coil 0|1")

		  Var coils() As Boolean = Array(True, False, True, True)
		  WriteMultipleCoils(10, coils, Nil, "FC15 write coils 10-13")
		  ReadCoils(10, 4, Nil, "FC01 read coils 10-13|1,0,1,1")

		  WriteSingleRegister(5, 1234, Nil, "FC06 write hr5")
		  ReadHoldingRegisters(5, 1, Nil, "FC03 read hr5|1234")

		  Var registerValues() As Integer = Array(1, -2, 65535)
		  WriteMultipleRegisters(100, registerValues, Nil, "FC16 write hr100-102")
		  ReadHoldingRegisters(100, 3, Nil, "FC03 read hr100-102|1,65534,65535")

		  Var words() As UInt16 = ModbusTypes.EncodeValue(kFloatValue, ModbusTypes.eDataType.Float32, ModbusTypes.eWordOrder.CDAB)
		  Var floatWrite As New ModbusRequest(ModbusTypes.eFunction.WriteMultipleRegisters, 200, words)
		  floatWrite.Tag = "FC16 write Float32 CDAB hr200"
		  Send(floatWrite)
		  ReadHoldingRegisters(200, 2, Nil, "FC03 read Float32 CDAB hr200|" + kExpectFloat)

		  ReadInputRegisters(0, 4, Nil, "FC04 read ir0-3|0,0,0,0")
		  ReadDiscreteInputs(0, 3, Nil, "FC02 read di0-2|0,0,0")

		  mExpected = 12
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mDone As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mExpected As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mFailures As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mReport() As String
	#tag EndProperty


	#tag Constant, Name = kExpectFloat, Type = String, Dynamic = False, Default = \"float", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kFail, Type = String, Dynamic = False, Default = \"FAIL", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kFloatValue, Type = Double, Dynamic = False, Default = \"21.5", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kPass, Type = String, Dynamic = False, Default = \"PASS", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTagSeparator, Type = String, Dynamic = False, Default = \"|", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
