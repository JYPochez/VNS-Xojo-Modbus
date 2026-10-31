#tag Class
Protected Class ModbusRequest
	#tag Method, Flags = &h0, Description = 456E636F6465732074686520636F6D706C657465204D6F6462757320525455206672616D653A20756E69742069643B205044553B204352432D313620286C6F772062797465206669727374292E0A
		Function BuildRTUFrame(defaultUnitID As Integer) As MemoryBlock
		  Var pdu As MemoryBlock = BuildPDU
		  Var frame As New MemoryBlock(pdu.Size + 3)
		  frame.LittleEndian = False
		  SentUnitID = If(UnitID >= 0, UnitID, defaultUnitID)
		  frame.UInt8Value(0) = SentUnitID
		  frame.StringValue(1, pdu.Size) = pdu
		  Var crc As Integer = ModbusTypes.CRC16(frame, pdu.Size + 1)
		  frame.UInt8Value(pdu.Size + 1) = crc And &hFF
		  frame.UInt8Value(pdu.Size + 2) = Bitwise.ShiftRight(crc, 8)
		  Return frame
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 456E636F6465732074686520636F6D706C657465204D6F6462757320544350206672616D6520284D42415020686561646572202B205044552920666F72207468697320726571756573742E0A
		Function BuildFrame(newTransactionID As Integer, defaultUnitID As Integer) As MemoryBlock
		  ' MBAP header: transaction id (2), protocol id = 0 (2), length of what follows (2), unit id (1).
		  Var pdu As MemoryBlock = BuildPDU
		  Var frame As New MemoryBlock(7 + pdu.Size)
		  frame.LittleEndian = False
		  frame.UInt16Value(0) = newTransactionID
		  frame.UInt16Value(2) = 0
		  frame.UInt16Value(4) = pdu.Size + 1
		  SentUnitID = If(UnitID >= 0, UnitID, defaultUnitID)
		  frame.UInt8Value(6) = SentUnitID
		  frame.StringValue(7, pdu.Size) = pdu
		  TransactionID = newTransactionID
		  Return frame
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 456E636F646573207468652070726F746F636F6C206461746120756E6974202866756E6374696F6E20636F646520616E6420646174612920736861726564206279204D6F646275732054435020616E64205254552E0A
		Function BuildPDU() As MemoryBlock
		  Var code As Integer = Integer(FunctionCode)
		  Var pdu As MemoryBlock
		  
		  Select Case FunctionCode
		  Case ModbusTypes.eFunction.WriteSingleCoil
		    pdu = New MemoryBlock(5)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(1) = Address
		    pdu.UInt16Value(3) = If(Values(0) <> 0, &hFF00, &h0000)
		    
		  Case ModbusTypes.eFunction.WriteSingleRegister
		    pdu = New MemoryBlock(5)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(1) = Address
		    pdu.UInt16Value(3) = Values(0)
		    
		  Case ModbusTypes.eFunction.WriteMultipleCoils
		    ' Coils are packed 8 per byte, first coil in the least significant bit.
		    Var byteCount As Integer = (Quantity + 7) \ 8
		    pdu = New MemoryBlock(6 + byteCount)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(1) = Address
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
		    pdu.UInt16Value(1) = Address
		    pdu.UInt16Value(3) = Quantity
		    pdu.UInt8Value(5) = Quantity * 2
		    For i As Integer = 0 To Quantity - 1
		      pdu.UInt16Value(6 + i * 2) = Values(i)
		    Next
		    
		  Case ModbusTypes.eFunction.ReadWriteMultipleRegisters
		    ' read address, read quantity, write address, write quantity, byte count, values
		    Var writeCount As Integer = WriteValues.Count
		    pdu = New MemoryBlock(10 + writeCount * 2)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(1) = Address
		    pdu.UInt16Value(3) = Quantity
		    pdu.UInt16Value(5) = WriteStartAddress
		    pdu.UInt16Value(7) = writeCount
		    pdu.UInt8Value(9) = writeCount * 2
		    For i As Integer = 0 To writeCount - 1
		      pdu.UInt16Value(10 + i * 2) = WriteValues(i)
		    Next
		    
		  Case ModbusTypes.eFunction.MaskWriteRegister
		    ' address, AND mask, OR mask
		    pdu = New MemoryBlock(7)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(1) = Address
		    pdu.UInt16Value(3) = Values(0)
		    pdu.UInt16Value(5) = Values(1)
		    
		  Case ModbusTypes.eFunction.Diagnostics
		    ' sub-function, then data words
		    pdu = New MemoryBlock(3 + Values.Count * 2)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(1) = SubFunction
		    For i As Integer = 0 To Values.LastIndex
		      pdu.UInt16Value(3 + i * 2) = Values(i)
		    Next
		    
		  Case ModbusTypes.eFunction.ReportServerID
		    pdu = New MemoryBlock(1)
		    
		  Case ModbusTypes.eFunction.EncapsulatedInterface
		    ' MEI type 0x0E (read device identification), category, first object
		    pdu = New MemoryBlock(4)
		    pdu.UInt8Value(1) = kMEIDeviceIdentification
		    pdu.UInt8Value(2) = DeviceIDCategory
		    pdu.UInt8Value(3) = FirstObjectID
		    
		  Else
		    ' FC 01 to 04: start address + quantity
		    pdu = New MemoryBlock(5)
		    pdu.LittleEndian = False
		    pdu.UInt16Value(1) = Address
		    pdu.UInt16Value(3) = Quantity
		  End Select
		  
		  pdu.UInt8Value(0) = code
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
		Sub Constructor(code As ModbusTypes.eFunction, startAddress As Integer, registerValues() As UInt16)
		  #Pragma BreakOnExceptions Off
		  Setup(code, startAddress, registerValues.Count)
		  If Not IsWrite Then Raise New InvalidArgumentException(ModbusTypes.kErrorInvalidQuantity)
		  For Each v As UInt16 In registerValues
		    Values.Add(v)
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 43726561746573206120526561642F5772697465204D756C7469706C6520526567697374657273207265717565737420284643203233293A2077726974657320777269746556616C756573206174207772697465416464726573732C207468656E2072656164732072656164436F756E74207265676973746572732066726F6D2072656164416464726573732E0A
		Sub Constructor(readAddress As Integer, readCount As Integer, writeAddress As Integer, registerValues() As UInt16)
		  #Pragma BreakOnExceptions Off
		  ' FC 23: the device writes first, then reads; Values() receives the registers read.
		  Setup(ModbusTypes.eFunction.ReadWriteMultipleRegisters, readAddress, readCount)
		  If writeAddress < 0 Or writeAddress > 65535 Then Raise New InvalidArgumentException(ModbusTypes.kErrorInvalidAddress)
		  If registerValues.Count < 1 Or registerValues.Count > ModbusTypes.kMaxReadWriteRegisters _
		    Or writeAddress + registerValues.Count > 65536 Then
		    Raise New InvalidArgumentException(ModbusTypes.kErrorInvalidQuantity)
		  End If
		  WriteStartAddress = writeAddress
		  For Each v As UInt16 In registerValues
		    WriteValues.Add(v)
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

	#tag Method, Flags = &h21
		Private Sub Constructor()
		  ' Used by the shared factories (MaskWrite, ReturnQueryData, ReportServerID, ReadDeviceIdentification).
		  Quantity = 1
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4643203232204D61736B2057726974652052656769737465723A20746865206465766963652073746F726573202863757272656E7420414E4420616E644D61736B29204F5220286F724D61736B20414E44204E4F5420616E644D61736B293B20736F20626974732063616E20626520736574206F7220636C656172656420776974686F75742072656164696E672066697273742E0A
		Shared Function MaskWrite(registerAddress As Integer, andMask As Integer, orMask As Integer) As ModbusRequest
		  #Pragma BreakOnExceptions Off
		  If registerAddress < 0 Or registerAddress > 65535 Then Raise New InvalidArgumentException(ModbusTypes.kErrorInvalidAddress)
		  If andMask < 0 Or andMask > 65535 Or orMask < 0 Or orMask > 65535 Then
		    Raise New InvalidArgumentException(ModbusTypes.kErrorValueOutOfRange)
		  End If
		  Var request As New ModbusRequest
		  request.FunctionCode = ModbusTypes.eFunction.MaskWriteRegister
		  request.Address = registerAddress
		  request.Values.Add(andMask)
		  request.Values.Add(orMask)
		  Return request
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseDeviceIdentification(pdu As MemoryBlock) As Boolean
		  ' 2B 0E category conformity moreFollows nextObject count, then id / length / value per object.
		  If pdu.Size < 7 Or pdu.UInt8Value(1) <> kMEIDeviceIdentification Then Return False
		  ConformityLevel = pdu.UInt8Value(3)
		  MoreFollows = (pdu.UInt8Value(4) = &hFF)
		  NextObjectID = pdu.UInt8Value(5)
		  Var count As Integer = pdu.UInt8Value(6)
		  
		  DeviceObjects = New Dictionary
		  Var position As Integer = 7
		  For i As Integer = 1 To count
		    If pdu.Size < position + 2 Then Return False
		    Var objectID As Integer = pdu.UInt8Value(position)
		    Var length As Integer = pdu.UInt8Value(position + 1)
		    If pdu.Size < position + 2 + length Then Return False
		    Var text As String = pdu.StringValue(position + 2, length)
		    DeviceObjects.Value(objectID) = text.DefineEncoding(Encodings.UTF8)
		    position = position + 2 + length
		  Next
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4643203433202F204D4549203134205265616420446576696365204964656E74696669636174696F6E2E2063617465676F72793A2031206261736963202876656E646F723B2070726F6475637420636F64653B207265766973696F6E293B203220726567756C61723B203320657874656E6465643B2034206F6E65207370656369666963206F626A656374202866697273744F626A6563744944292E0A
		Shared Function ReadDeviceIdentification(category As Integer = 1, firstObjectID As Integer = 0) As ModbusRequest
		  #Pragma BreakOnExceptions Off
		  If category < 1 Or category > 4 Or firstObjectID < 0 Or firstObjectID > 255 Then
		    Raise New InvalidArgumentException(ModbusTypes.kErrorValueOutOfRange)
		  End If
		  Var request As New ModbusRequest
		  request.FunctionCode = ModbusTypes.eFunction.EncapsulatedInterface
		  request.DeviceIDCategory = category
		  request.FirstObjectID = firstObjectID
		  Return request
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4643203137205265706F7274205365727665722049443A206465766963652D7370656369666963206964656E74696669636174696F6E2062797465733B2072657475726E656420696E20526573706F6E736542797465732E0A
		Shared Function ReportServerID() As ModbusRequest
		  Var request As New ModbusRequest
		  request.FunctionCode = ModbusTypes.eFunction.ReportServerID
		  Return request
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 464320303820446961676E6F73746963733B207375622D66756E6374696F6E2030302052657475726E20517565727920446174613A20746865206465766963652073656E6473206261636B20746865206461746120756E6368616E676564202861206C6F6F706261636B2074657374206F6620746865206C696E65292E0A
		Shared Function ReturnQueryData(data As Integer) As ModbusRequest
		  #Pragma BreakOnExceptions Off
		  If data < 0 Or data > 65535 Then Raise New InvalidArgumentException(ModbusTypes.kErrorValueOutOfRange)
		  Var request As New ModbusRequest
		  request.FunctionCode = ModbusTypes.eFunction.Diagnostics
		  request.SubFunction = 0
		  request.Values.Add(data)
		  Return request
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function SameBytes(first As MemoryBlock, second As MemoryBlock) As Boolean
		  If first.Size <> second.Size Then Return False
		  For i As Integer = 0 To first.Size - 1
		    If first.UInt8Value(i) <> second.UInt8Value(i) Then Return False
		  Next
		  Return True
		End Function
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

		  Case ModbusTypes.eFunction.ReadHoldingRegisters, ModbusTypes.eFunction.ReadInputRegisters, _
		    ModbusTypes.eFunction.ReadWriteMultipleRegisters
		    Var byteCount As Integer = pdu.UInt8Value(1)
		    If byteCount <> Quantity * 2 Or pdu.Size < 2 + byteCount Then
		      Fail(ModbusTypes.eError.InvalidResponse)
		      Return False
		    End If
		    Values.RemoveAll
		    For i As Integer = 0 To Quantity - 1
		      Values.Add(pdu.UInt16Value(2 + i * 2))
		    Next

		  Case ModbusTypes.eFunction.MaskWriteRegister
		    ' Echo of the address and both masks.
		    If pdu.Size < 7 Or pdu.UInt16Value(1) <> Address Or pdu.UInt16Value(3) <> Values(0) _
		      Or pdu.UInt16Value(5) <> Values(1) Then
		      Fail(ModbusTypes.eError.InvalidResponse)
		      Return False
		    End If
		    
		  Case ModbusTypes.eFunction.Diagnostics
		    ' Return Query Data is a loopback: the answer must be the request, byte for byte.
		    Var sent As MemoryBlock = BuildPDU
		    If Not SameBytes(pdu, sent) Then
		      Fail(ModbusTypes.eError.InvalidResponse)
		      Return False
		    End If
		    
		  Case ModbusTypes.eFunction.ReportServerID
		    Var byteCount As Integer = pdu.UInt8Value(1)
		    If pdu.Size < 2 + byteCount Then
		      Fail(ModbusTypes.eError.InvalidResponse)
		      Return False
		    End If
		    ResponseBytes = pdu.StringValue(2, byteCount)
		    Values.RemoveAll
		    For i As Integer = 0 To byteCount - 1
		      Values.Add(ResponseBytes.UInt8Value(i))
		    Next
		    
		  Case ModbusTypes.eFunction.EncapsulatedInterface
		    If Not ParseDeviceIdentification(pdu) Then
		      Fail(ModbusTypes.eError.InvalidResponse)
		      Return False
		    End If
		    
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
		  Case ModbusTypes.eFunction.ReadHoldingRegisters, ModbusTypes.eFunction.ReadInputRegisters, _
		    ModbusTypes.eFunction.ReadWriteMultipleRegisters
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

	#tag ComputedProperty, Flags = &h0, Description = 5472756520666F722046432030353B2030363B2031353B20313620616E642032322E0A
		#tag Getter
			Get
			  Select Case FunctionCode
			  Case ModbusTypes.eFunction.WriteSingleCoil, ModbusTypes.eFunction.WriteSingleRegister, _
			    ModbusTypes.eFunction.WriteMultipleCoils, ModbusTypes.eFunction.WriteMultipleRegisters, _
			    ModbusTypes.eFunction.MaskWriteRegister
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

	#tag Property, Flags = &h0, Description = 556E69742069642061637475616C6C792073656E742028556E69744944206F722074686520636C69656E7427732064656661756C74293B20736574207768656E20746865206672616D65206973206275696C742E0A
		SentUnitID As Integer
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


	#tag Property, Flags = &h0, Description = 4643203233206F6E6C793A206669727374207265676973746572207772697474656E2E0A
		WriteStartAddress As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4643203233206F6E6C793A20726567697374657273207772697474656E206265666F72652074686520726561643B2056616C756573282920686F6C6473207468652072656769737465727320726561642E0A
		WriteValues() As UInt16
	#tag EndProperty


	#tag Property, Flags = &h0, Description = 46432034333A20636F6E666F726D697479206C6576656C207265706F7274656420627920746865206465766963652E0A
		ConformityLevel As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46432034333A2063617465676F72792061736B65642028312062617369633B203220726567756C61723B203320657874656E6465643B2034206F6E65206F626A656374292E0A
		DeviceIDCategory As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46432034333A206F626A656374732072656365697665643B206F626A6563742069642028496E746567657229202D3E20746578742E20302076656E646F723B20312070726F6475637420636F64653B2032207265766973696F6E3B20332076656E646F722055524C3B20342070726F64756374206E616D653B2035206D6F64656C3B2036206170706C69636174696F6E2E0A
		DeviceObjects As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46432034333A206669727374206F626A6563742061736B65642E0A
		FirstObjectID As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46432034333A2054727565207768656E207468652064657669636520686173206D6F7265206F626A656374733B2061736B20616761696E2066726F6D204E6578744F626A65637449442E0A
		MoreFollows As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46432034333A206F626A65637420746F2061736B206E657874207768656E204D6F7265466F6C6C6F777320697320547275652E0A
		NextObjectID As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46432031373A20746865206964656E74696669636174696F6E2062797465732073656E7420627920746865206465766963652028746865206C617374206F6E6520697320757375616C6C79207468652072756E20696E64696361746F723A204646203D2072756E6E696E67292E0A
		ResponseBytes As MemoryBlock
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46432030383A20646961676E6F7374696373207375622D66756E6374696F6E202830203D2052657475726E2051756572792044617461292E0A
		SubFunction As Integer
	#tag EndProperty

	#tag Constant, Name = kMEIDeviceIdentification, Type = Integer, Dynamic = False, Default = \"14", Scope = Private
	#tag EndConstant


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
