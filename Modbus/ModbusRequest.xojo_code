#tag Class
Protected Class ModbusRequest
	#tag Method, Flags = &h0, Description = 456E636F6465732074686520636F6D706C657465204D6F6462757320544350206672616D6520284D42415020686561646572202B205044552920666F72207468697320726571756573742E0A
		Function BuildFrame(newTransactionID As Integer, defaultUnitID As Integer) As MemoryBlock
		  ' MBAP header: transaction id (2), protocol id = 0 (2), length of what follows (2), unit id (1).
		  Var pdu As MemoryBlock = BuildPDU
		  Var frame As New MemoryBlock(7 + pdu.Size)
		  frame.LittleEndian = False
		  frame.UInt16Value(0) = newTransactionID
		  frame.UInt16Value(2) = 0
		  frame.UInt16Value(4) = pdu.Size + 1
		  frame.UInt8Value(6) = If(UnitID >= 0, UnitID, defaultUnitID)
		  frame.StringValue(7, pdu.Size) = pdu
		  TransactionID = newTransactionID
		  Return frame
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function BuildPDU() As MemoryBlock
		  Var code As Integer = Integer(FunctionCode)
		  Var pdu As MemoryBlock

		  Select Case FunctionCode
		  Case ModbusTypes.eFunction.WriteSingleCoil
		    pdu = New MemoryBlock(5)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(3) = If(Values(0) <> 0, &hFF00, &h0000)

		  Case ModbusTypes.eFunction.WriteSingleRegister
		    pdu = New MemoryBlock(5)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(3) = Values(0)

		  Case ModbusTypes.eFunction.WriteMultipleCoils
		    ' Coils are packed 8 per byte, first coil in the least significant bit.
		    Var byteCount As Integer = (Quantity + 7) \ 8
		    pdu = New MemoryBlock(6 + byteCount)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(3) = Quantity
		    pdu.UInt8Value(5) = byteCount
		    For i As Integer = 0 To Quantity - 1
		      If Values(i) <> 0 Then
		        Var bytePosition As Integer = 6 + i \ 8
		        pdu.UInt8Value(bytePosition) = pdu.UInt8Value(bytePosition) Or Bitwise.ShiftLeft(1, i Mod 8)
		      End If
		    Next

		  Case ModbusTypes.eFunction.WriteMultipleRegisters
		    pdu = New MemoryBlock(6 + Quantity * 2)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(3) = Quantity
		    pdu.UInt8Value(5) = Quantity * 2
		    For i As Integer = 0 To Quantity - 1
		      pdu.UInt16Value(6 + i * 2) = Values(i)
		    Next

		  Else
		    ' FC 01 to 04: start address + quantity
		    pdu = New MemoryBlock(5)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(3) = Quantity
		  End Select

		  pdu.UInt8Value(0) = code
		  pdu.UInt16Value(1) = Address
		  Return pdu
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 437265617465732061207265616420726571756573742028464320303120746F203034293A20636F756E7420726567697374657273206F7220626974732066726F6D207374617274416464726573732E0A
		Sub Constructor(code As ModbusTypes.eFunction, startAddress As Integer, count As Integer)
		  #Pragma BreakOnExceptions Off
		  Setup(code, startAddress, count)
		  If IsWrite Then Raise New InvalidArgumentException(ModbusTypes.kErrorInvalidQuantity)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4372656174657320612077726974652072657175657374202846432030353B2030363B203135206F72203136292E20777269746556616C75657320686F6C6473207468652072656769737465727320746F2073656E643B206F7220302F312070657220636F696C2E0A
		Sub Constructor(code As ModbusTypes.eFunction, startAddress As Integer, writeValues() As UInt16)
		  #Pragma BreakOnExceptions Off
		  Setup(code, startAddress, writeValues.Count)
		  If Not IsWrite Then Raise New InvalidArgumentException(ModbusTypes.kErrorInvalidQuantity)
		  For Each v As UInt16 In writeValues
		    Values.Add(v)
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 5265636F7264732061206661696C7572653A2073657473204572726F72436F646520616E64204572726F724D6573736167652E0A
		Sub Fail(code As ModbusTypes.eError, message As String = "")
		  ErrorCode = code
		  ErrorMessage = If(message = "", ModbusTypes.ErrorText(code), message)
		  IsDone = True
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4465636F6465732074686520726573706F6E736520504455202866756E6374696F6E20636F6465206F6E7761726473292E2052657475726E732054727565206F6E20737563636573733B206F7468657277697365204572726F72436F64652074656C6C73207768792E0A
		Function ParseResponse(pdu As MemoryBlock) As Boolean
		  IsDone = True
		  If pdu Is Nil Or pdu.Size < 2 Then
		    Fail(ModbusTypes.eError.InvalidResponse)
		    Return False
		  End If
		  pdu.LittleEndian = False

		  Var code As Integer = pdu.UInt8Value(0)
		  If code = Integer(FunctionCode) + &h80 Then
		    ExceptionCode = pdu.UInt8Value(1)
		    Fail(ModbusTypes.eError.ExceptionResponse, ModbusTypes.ExceptionText(ExceptionCode))
		    Return False
		  End If
		  If code <> Integer(FunctionCode) Then
		    Fail(ModbusTypes.eError.InvalidResponse)
		    Return False
		  End If

		  Select Case FunctionCode
		  Case ModbusTypes.eFunction.ReadCoils, ModbusTypes.eFunction.ReadDiscreteInputs
		    Var byteCount As Integer = pdu.UInt8Value(1)
		    If byteCount < (Quantity + 7) \ 8 Or pdu.Size < 2 + byteCount Then
		      Fail(ModbusTypes.eError.InvalidResponse)
		      Return False
		    End If
		    Values.RemoveAll
		    For i As Integer = 0 To Quantity - 1
		      Var packed As Integer = pdu.UInt8Value(2 + i \ 8)
		      Values.Add(If((packed And Bitwise.ShiftLeft(1, i Mod 8)) <> 0, 1, 0))
		    Next

		  Case ModbusTypes.eFunction.ReadHoldingRegisters, ModbusTypes.eFunction.ReadInputRegisters
		    Var byteCount As Integer = pdu.UInt8Value(1)
		    If byteCount <> Quantity * 2 Or pdu.Size < 2 + byteCount Then
		      Fail(ModbusTypes.eError.InvalidResponse)
		      Return False
		    End If
		    Values.RemoveAll
		    For i As Integer = 0 To Quantity - 1
		      Values.Add(pdu.UInt16Value(2 + i * 2))
		    Next

		  Else
		    ' Writes echo the start address and the value (FC 05, 06) or the quantity (FC 15, 16).
		    Var expected As Integer = Quantity
		    If FunctionCode = ModbusTypes.eFunction.WriteSingleCoil Then
		      expected = If(Values(0) <> 0, &hFF00, &h0000)
		    ElseIf FunctionCode = ModbusTypes.eFunction.WriteSingleRegister Then
		      expected = Values(0)
		    End If
		    If pdu.Size < 5 Or pdu.UInt16Value(1) <> Address Or pdu.UInt16Value(3) <> expected Then
		      Fail(ModbusTypes.eError.InvalidResponse)
		      Return False
		    End If
		  End Select

		  ErrorCode = ModbusTypes.eError.None
		  ErrorMessage = ""
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Setup(code As ModbusTypes.eFunction, startAddress As Integer, count As Integer)
		  #Pragma BreakOnExceptions Off
		  ' Invalid arguments are programming errors, so they raise instead of failing at run time.
		  If startAddress < 0 Or startAddress > 65535 Then
		    Raise New InvalidArgumentException(ModbusTypes.kErrorInvalidAddress)
		  End If
		  
		  Var maximum As Integer
		  Select Case code
		  Case ModbusTypes.eFunction.ReadCoils, ModbusTypes.eFunction.ReadDiscreteInputs
		    maximum = ModbusTypes.kMaxReadBits
		  Case ModbusTypes.eFunction.ReadHoldingRegisters, ModbusTypes.eFunction.ReadInputRegisters
		    maximum = ModbusTypes.kMaxReadRegisters
		  Case ModbusTypes.eFunction.WriteMultipleCoils
		    maximum = ModbusTypes.kMaxWriteBits
		  Case ModbusTypes.eFunction.WriteMultipleRegisters
		    maximum = ModbusTypes.kMaxWriteRegisters
		  Else
		    maximum = 1
		  End Select
		  If count < 1 Or count > maximum Or startAddress + count > 65536 Then
		    Raise New InvalidArgumentException(ModbusTypes.kErrorInvalidQuantity)
		  End If
		  
		  FunctionCode = code
		  Address = startAddress
		  Quantity = count
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4465636F64657320612076616C75652066726F6D20746865207265676973746572732072656164206279207468697320726571756573742E206F666673657420697320636F756E74656420696E207265676973746572732066726F6D207468652072657175657374277320737461727420616464726573732E0A
		Function ValueAt(offset As Integer, dataType As ModbusTypes.eDataType, order As ModbusTypes.eWordOrder = ModbusTypes.eWordOrder.ABCD) As Double
		  Return ModbusTypes.DecodeValue(Values, offset, dataType, order)
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0, Description = 537461727420616464726573732028302D62617365642070726F746F636F6C2061646472657373292E0A
		Address As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4F7074696F6E616C206D6574686F642063616C6C6564207768656E2074686520726571756573742066696E69736865732E205768656E207365742C2074686520636C69656E7420646F6573206E6F742072616973652052657175657374436F6D706C65746564202F20526571756573744661696C656420666F72207468697320726571756573742E0A
		Callback As ModbusTypes.RequestCallback
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4E6F6E65206F6E20737563636573733B206F746865727769736520776879207468652072657175657374206661696C65642E0A
		ErrorCode As ModbusTypes.eError
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 5265616461626C65207465787420666F72204572726F72436F64652028456E676C697368292E0A
		ErrorMessage As String
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 457863657074696F6E20636F64652073656E742062792074686520646576696365207768656E204572726F72436F646520697320457863657074696F6E526573706F6E7365202831203D20696C6C6567616C2066756E6374696F6E3B2032203D20696C6C6567616C2061646472657373E280A6292E0A
		ExceptionCode As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 546865204D6F646275732066756E6374696F6E206F66207468697320726571756573742E0A
		FunctionCode As ModbusTypes.eFunction
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 54727565206F6E6365207468652072657175657374206861732066696E69736865643A20616E7377657265642C206661696C6564206F722063616E63656C6C65642E0A
		IsDone As Boolean
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 5472756520666F722046432030353B2030363B20313520616E642031362E0A
		#tag Getter
			Get
			  Select Case FunctionCode
			  Case ModbusTypes.eFunction.WriteSingleCoil, ModbusTypes.eFunction.WriteSingleRegister, _
			    ModbusTypes.eFunction.WriteMultipleCoils, ModbusTypes.eFunction.WriteMultipleRegisters
			    Return True
			  Else
			    Return False
			  End Select
			End Get
		#tag EndGetter
		IsWrite As Boolean
	#tag EndComputedProperty

	#tag Property, Flags = &h0, Description = 4E756D626572206F6620726567697374657273206F7220626974732072656164206F72207772697474656E2E0A
		Quantity As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 54696D65206265747765656E2073656E64696E6720746865207265717565737420616E6420726563656976696E672074686520616E737765723B20696E206D696C6C697365636F6E64732E0A
		ResponseTimeMS As Double
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 53797374656D2E4D6963726F7365636F6E6473207768656E207468652072657175657374207761732073656E743B207573656420746F20636F6D7075746520526573706F6E736554696D654D532E0A
		SentMicroseconds As Double
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 54727565207768656E2074686520726571756573742066696E697368656420776974686F7574206572726F722E0A
		#tag Getter
			Get
			  Return IsDone And ErrorCode = ModbusTypes.eError.None
			End Get
		#tag EndGetter
		Succeeded As Boolean
	#tag EndComputedProperty

	#tag Property, Flags = &h0, Description = 467265652076616C756520666F72207468652063616C6C65723B20666F72206578616D706C6520776861742074686520616E7377657220697320666F722E204E6F74207573656420627920746865206C6962726172792E0A
		Tag As Variant
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4D6F6462757320544350207472616E73616374696F6E206964656E7469666965722061737369676E6564207768656E20746865206672616D65206973206275696C742E0A
		TransactionID As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 556E69742028736C6176652920696420666F72207468697320726571756573742E202D3120757365732074686520636C69656E74277320556E697449442E0A
		UnitID As Integer = -1
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 5265676973746572732072656164206F7220746F2077726974652E20466F7220636F696C7320616E6420646973637265746520696E70757473206561636820656E7472792069732030206F7220312E0A
		Values() As UInt16
	#tag EndProperty


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
