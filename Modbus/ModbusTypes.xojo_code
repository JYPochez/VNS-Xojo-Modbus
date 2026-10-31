#tag Module
Protected Module ModbusTypes
	#tag Method, Flags = &h1, Description = 52657475726E73207468652074776F2D6C6574746572206172656120707265666978207573656420696E20706F696E74206164647265737365733A20636F2C2064692C206872206F722069722E0A
		Protected Function AreaPrefix(area As ModbusTypes.eArea) As String
		  Select Case area
		  Case ModbusTypes.eArea.Coil
		    Return kPrefixCoil
		  Case ModbusTypes.eArea.DiscreteInput
		    Return kPrefixDiscreteInput
		  Case ModbusTypes.eArea.InputRegister
		    Return kPrefixInputRegister
		  Else
		    Return kPrefixHoldingRegister
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 52657475726E73207468652066756E6374696F6E20636F646520746861742072656164732074686520676976656E20617265612028464320303120746F203034292E0A
		Protected Function AreaReadFunction(area As ModbusTypes.eArea) As ModbusTypes.eFunction
		  Select Case area
		  Case ModbusTypes.eArea.Coil
		    Return ModbusTypes.eFunction.ReadCoils
		  Case ModbusTypes.eArea.DiscreteInput
		    Return ModbusTypes.eFunction.ReadDiscreteInputs
		  Case ModbusTypes.eArea.InputRegister
		    Return ModbusTypes.eFunction.ReadInputRegisters
		  Else
		    Return ModbusTypes.eFunction.ReadHoldingRegisters
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 4352432D3136206F6620746865206669727374206C656E6774682062797465732C2061732075736564206279204D6F64627573205254552028706F6C796E6F6D69616C20413030312C20696E697469616C2076616C75652046464646292E20546865206C6F7720627974652069732073656E742066697273742E0A
		Protected Function CRC16(bytes As MemoryBlock, length As Integer) As Integer
		  Var crc As Integer = &hFFFF
		  For i As Integer = 0 To length - 1
		    crc = Bitwise.BitXor(crc, bytes.UInt8Value(i))
		    For bit As Integer = 1 To 8
		      If (crc And 1) <> 0 Then
		        crc = Bitwise.BitXor(Bitwise.ShiftRight(crc, 1), &hA001)
		      Else
		        crc = Bitwise.ShiftRight(crc, 1)
		      End If
		    Next
		  Next
		  Return crc
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 4465636F646573207468652076616C756520746861742073746172747320617420696E64657820696E20612072656769737465722061727261792E2054776F2D20616E6420666F75722D7265676973746572207479706573207573652074686520676976656E20776F7264206F726465722E0A
		Protected Function DecodeValue(registers() As UInt16, index As Integer, dataType As ModbusTypes.eDataType, order As ModbusTypes.eWordOrder = ModbusTypes.eWordOrder.ABCD) As Double
		  #Pragma BreakOnExceptions Off
		  ' 16-bit types are read directly; wider types are rebuilt as big-endian bytes in a
		  ' MemoryBlock (see RegistersToBytes) and read back with the matching accessor.
		  Var count As Integer = RegisterCount(dataType)
		  If index < 0 Or index + count - 1 > registers.LastIndex Then
		    Raise New OutOfBoundsException
		  End If

		  Select Case dataType
		  Case ModbusTypes.eDataType.Bit, ModbusTypes.eDataType.Unsigned16
		    Return registers(index)
		  Case ModbusTypes.eDataType.Signed16
		    Return ToSigned16(registers(index))
		  End Select

		  Var bytes As MemoryBlock = RegistersToBytes(registers, index, count, order)
		  Select Case dataType
		  Case ModbusTypes.eDataType.Unsigned32
		    Return bytes.UInt32Value(0)
		  Case ModbusTypes.eDataType.Signed32
		    Return bytes.Int32Value(0)
		  Case ModbusTypes.eDataType.Float32
		    Return bytes.SingleValue(0)
		  Else
		    Return bytes.DoubleValue(0)
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 456E636F64657320612076616C756520696E746F207468652072656769737465727320746F2077726974652E2052616973657320496E76616C6964417267756D656E74457863657074696F6E207768656E207468652076616C756520646F6573206E6F742066697420746865206461746120747970652E0A
		Protected Function EncodeValue(value As Double, dataType As ModbusTypes.eDataType, order As ModbusTypes.eWordOrder = ModbusTypes.eWordOrder.ABCD) As UInt16()
		  #Pragma BreakOnExceptions Off
		  Var result() As UInt16
		  If value.IsNotANumber Or value.IsInfinite Then Raise New InvalidArgumentException(kErrorValueOutOfRange)
		  Var whole As Double = Round(value)

		  Select Case dataType
		  Case ModbusTypes.eDataType.Bit
		    result.Add(If(value <> 0, 1, 0))
		    Return result

		  Case ModbusTypes.eDataType.Unsigned16
		    If whole < 0 Or whole > 65535 Then Raise New InvalidArgumentException(kErrorValueOutOfRange)
		    result.Add(whole)
		    Return result

		  Case ModbusTypes.eDataType.Signed16
		    If whole < -32768 Or whole > 32767 Then Raise New InvalidArgumentException(kErrorValueOutOfRange)
		    If whole < 0 Then whole = whole + 65536
		    result.Add(whole)
		    Return result
		  End Select

		  ' Wider types: write the value big-endian, then lay the words out in the requested order.
		  Var count As Integer = RegisterCount(dataType)
		  Var bytes As New MemoryBlock(count * 2)
		  bytes.LittleEndian = False
		  Select Case dataType
		  Case ModbusTypes.eDataType.Unsigned32
		    If whole < 0 Or whole > 4294967295.0 Then Raise New InvalidArgumentException(kErrorValueOutOfRange)
		    bytes.UInt32Value(0) = whole
		  Case ModbusTypes.eDataType.Signed32
		    If whole < -2147483648.0 Or whole > 2147483647.0 Then Raise New InvalidArgumentException(kErrorValueOutOfRange)
		    bytes.Int32Value(0) = whole
		  Case ModbusTypes.eDataType.Float32
		    If Abs(value) > kMaxFloat32 Then Raise New InvalidArgumentException(kErrorValueOutOfRange)
		    bytes.SingleValue(0) = value
		  Else
		    bytes.DoubleValue(0) = value
		  End Select

		  Var wordsReversed As Boolean = (order = ModbusTypes.eWordOrder.CDAB Or order = ModbusTypes.eWordOrder.DCBA)
		  Var bytesSwapped As Boolean = (order = ModbusTypes.eWordOrder.BADC Or order = ModbusTypes.eWordOrder.DCBA)
		  For i As Integer = 0 To count - 1
		    Var source As Integer = If(wordsReversed, count - 1 - i, i)
		    Var word As Integer = bytes.UInt16Value(source * 2)
		    If bytesSwapped Then word = SwapBytes(word)
		    result.Add(word)
		  Next
		  Return result
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 52657475726E732061207265616461626C6520456E676C697368207465787420666F7220616E206572726F7220636F64652E0A
		Protected Function ErrorText(code As ModbusTypes.eError) As String
		  Select Case code
		  Case ModbusTypes.eError.None
		    Return kErrorNone
		  Case ModbusTypes.eError.NotConnected
		    Return kErrorNotConnected
		  Case ModbusTypes.eError.ConnectFailed
		    Return kErrorConnectFailed
		  Case ModbusTypes.eError.ConnectionLost
		    Return kErrorConnectionLost
		  Case ModbusTypes.eError.Timeout
		    Return kErrorTimeout
		  Case ModbusTypes.eError.ExceptionResponse
		    Return kErrorExceptionResponse
		  Case ModbusTypes.eError.InvalidResponse
		    Return kErrorInvalidResponse
		  Case ModbusTypes.eError.Cancelled
		    Return kErrorCancelled
		  Case ModbusTypes.eError.InvalidRequest
		    Return kErrorInvalidRequest
		  Else
		    Return kErrorUnknown
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 52657475726E7320746865207374616E64617264206E616D65206F662061204D6F6462757320657863657074696F6E20636F646520283120746F203131292073656E74206261636B2062792061206465766963652E0A
		Protected Function ExceptionText(code As Integer) As String
		  Select Case code
		  Case 1
		    Return kException1
		  Case 2
		    Return kException2
		  Case 3
		    Return kException3
		  Case 4
		    Return kException4
		  Case 5
		    Return kException5
		  Case 6
		    Return kException6
		  Case 8
		    Return kException8
		  Case 10
		    Return kException10
		  Case 11
		    Return kException11
		  Else
		    Return kExceptionUnknown + " " + code.ToString
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 4E756D626572206F662031362D6269742072656769737465727320757365642062792061206461746120747970653A203120666F722042697420616E642031362D6269742074797065733B203220666F722033322D6269743B203420666F7220466C6F617436342E0A
		Protected Function RegisterCount(dataType As ModbusTypes.eDataType) As Integer
		  Select Case dataType
		  Case ModbusTypes.eDataType.Unsigned32, ModbusTypes.eDataType.Signed32, ModbusTypes.eDataType.Float32
		    Return 2
		  Case ModbusTypes.eDataType.Float64
		    Return 4
		  Else
		    Return 1
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 546F74616C206C656E677468206F66207468652052545520616E7377657220746861742073746172747320746865206275666665722028756E69743B2066756E6374696F6E3B20646174613B20435243293B2030207768696C65206D6F726520627974657320617265206E65656465643B202D3120666F7220616E20756E6B6E6F776E2066756E6374696F6E20636F64652E207265717565737450445553697A653A2073697A65206F66207468652072657175657374205044552028464320303820616E73776572732068617665207468652073616D652073697A65292E0A
		Protected Function RTUResponseLength(buffer As MemoryBlock, requestPDUSize As Integer = 0) As Integer
		  ' RTU frames carry no length field: it follows from the function code and the byte count.
		  ' requestPDUSize is needed for FC 08, whose answer has the size of the request.
		  If buffer Is Nil Or buffer.Size < 2 Then Return 0
		  Var code As Integer = buffer.UInt8Value(1)
		  If (code And &h80) <> 0 Then Return 5
		  Select Case code
		  Case 1, 2, 3, 4, 17, 23
		    If buffer.Size < 3 Then Return 0
		    Return 5 + buffer.UInt8Value(2)
		  Case 5, 6, 15, 16
		    Return 8
		  Case 8
		    If requestPDUSize > 0 Then Return requestPDUSize + 3
		    Return 8
		  Case 22
		    Return 10
		  Case 43
		    ' unit, 2B, 0E, category, conformity, more, next, count; then id / length / value
		    If buffer.Size < 8 Then Return 0
		    Var position As Integer = 8
		    For i As Integer = 1 To buffer.UInt8Value(7)
		      If buffer.Size < position + 2 Then Return 0
		      position = position + 2 + buffer.UInt8Value(position + 1)
		    Next
		    Return position + 2
		  Else
		    Return -1
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function RegistersToBytes(registers() As UInt16, index As Integer, count As Integer, order As ModbusTypes.eWordOrder) As MemoryBlock
		  ' Rebuilds the big-endian byte image of a multi-register value.
		  ' ABCD: registers in order, high byte first (the Modbus default)
		  ' CDAB: register order reversed (low word first)
		  ' BADC: bytes swapped inside each register
		  ' DCBA: both (fully little-endian)
		  Var wordsReversed As Boolean = (order = ModbusTypes.eWordOrder.CDAB Or order = ModbusTypes.eWordOrder.DCBA)
		  Var bytesSwapped As Boolean = (order = ModbusTypes.eWordOrder.BADC Or order = ModbusTypes.eWordOrder.DCBA)

		  Var bytes As New MemoryBlock(count * 2)
		  bytes.LittleEndian = False
		  For i As Integer = 0 To count - 1
		    Var source As Integer = If(wordsReversed, index + count - 1 - i, index + i)
		    Var word As Integer = registers(source)
		    If bytesSwapped Then word = SwapBytes(word)
		    bytes.UInt16Value(i * 2) = word
		  Next
		  Return bytes
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 5265616461626C6520456E676C697368207465787420666F72206120736F636B6574206572726F72206E756D6265722028586F6A6F20636F646573203130322D31303720616E6420636F6D6D6F6E206D61634F53202F204C696E7578202F2057696E646F7773206E6574776F726B206572726F7273292E0A
		Protected Function SocketErrorText(code As Integer) As String
		  ' Xojo socket codes first; then the operating-system codes of macOS; Linux and Windows.
		  Select Case code
		  Case 102
		    Return kSocketLost
		  Case 103
		    Return kSocketNoName
		  Case 105
		    Return kSocketAddressInUse
		  Case 107
		    Return kSocketInvalidPort
		  Case 51, 101, 10051
		    Return kSocketNetworkUnreachable
		  Case 60, 110, 10060
		    Return kSocketTimedOut
		  Case 61, 111, 10061
		    Return kSocketRefused
		  Case 64, 112, 10064
		    Return kSocketHostDown
		  Case 65
		    ' macOS also answers "no route" when the app lacks the Local Network permission.
		    Return kSocketNoRouteMac
		  Case 113, 10065
		    Return kSocketNoRoute
		  Else
		    Return kErrorUnknown
		  End Select
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function SwapBytes(word As Integer) As Integer
		  Return (word Mod 256) * 256 + (word \ 256)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 436F6E76657274732061207261772031362D62697420726567697374657220283020746F2036353533352920746F20697473207369676E65642076616C756520282D333237363820746F203332373637292E0A
		Protected Function ToSigned16(value As Integer) As Integer
		  If value >= 32768 Then Return value - 65536
		  Return value
		End Function
	#tag EndMethod


	#tag DelegateDeclaration, Flags = &h1, Description = 43616C6C6564206279204D6F64627573544350436C69656E74207768656E206120726571756573742074686174206361727269657320612063616C6C6261636B206861732066696E69736865642C207375636365737366756C6C79206F72206E6F742E0A
		Protected Delegate Sub RequestCallback(request As ModbusRequest)
	#tag EndDelegateDeclaration


	#tag Constant, Name = kDefaultPort, Type = Integer, Dynamic = False, Default = \"502", Scope = Protected, Description = 5374616E64617264204D6F646275732054435020706F72742E0A
	#tag EndConstant

	#tag Constant, Name = kErrorBroadcastRead, Type = String, Dynamic = False, Default = \"Unit 0 (broadcast) can only write: nobody answers a broadcast", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorCRC, Type = String, Dynamic = False, Default = \"CRC error in the answer", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorInvalidRequest, Type = String, Dynamic = False, Default = \"Request not possible", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorNoPort, Type = String, Dynamic = False, Default = \"Serial port not found:", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorWrongUnit, Type = String, Dynamic = False, Default = \"Answer from another unit id", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorCancelled, Type = String, Dynamic = False, Default = \"Request cancelled", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorConnectFailed, Type = String, Dynamic = False, Default = \"Could not connect to the device", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorConnectionLost, Type = String, Dynamic = False, Default = \"Connection lost", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorDisconnected, Type = String, Dynamic = False, Default = \"Disconnected: call Connect first", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorExceptionResponse, Type = String, Dynamic = False, Default = \"The device answered with an exception", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorInvalidQuantity, Type = String, Dynamic = False, Default = \"Invalid quantity for this function code", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorInvalidAddress, Type = String, Dynamic = False, Default = \"Address out of the 0 to 65535 range", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorInvalidResponse, Type = String, Dynamic = False, Default = \"Malformed response from the device", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorNone, Type = String, Dynamic = False, Default = \"No error", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorNotConnected, Type = String, Dynamic = False, Default = \"Not connected", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorNoAddress, Type = String, Dynamic = False, Default = \"No device address set", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorTimeout, Type = String, Dynamic = False, Default = \"No response from the device (timeout)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorUnknown, Type = String, Dynamic = False, Default = \"Unknown error", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorValueOutOfRange, Type = String, Dynamic = False, Default = \"Value out of range for the data type", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kErrorConnectTimeout, Type = String, Dynamic = False, Default = \"Connection timed out", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException1, Type = String, Dynamic = False, Default = \"Illegal function (exception 1)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException10, Type = String, Dynamic = False, Default = \"Gateway path unavailable (exception 10)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException11, Type = String, Dynamic = False, Default = \"Gateway target device failed to respond (exception 11)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException2, Type = String, Dynamic = False, Default = \"Illegal data address (exception 2)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException3, Type = String, Dynamic = False, Default = \"Illegal data value (exception 3)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException4, Type = String, Dynamic = False, Default = \"Server device failure (exception 4)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException5, Type = String, Dynamic = False, Default = \"Acknowledge: request accepted but still processing (exception 5)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException6, Type = String, Dynamic = False, Default = \"Server device busy (exception 6)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kException8, Type = String, Dynamic = False, Default = \"Memory parity error (exception 8)", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kExceptionUnknown, Type = String, Dynamic = False, Default = \"Unknown exception", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kMaxFloat32, Type = Double, Dynamic = False, Default = \"3.4028234663852886e38", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kMaxReadBits, Type = Integer, Dynamic = False, Default = \"2000", Scope = Protected, Description = 4C617267657374206E756D626572206F6620636F696C73206F7220646973637265746520696E7075747320696E206F6E6520726561642028464320303120616E64203032292E0A
	#tag EndConstant

	#tag Constant, Name = kMaxReadRegisters, Type = Integer, Dynamic = False, Default = \"125", Scope = Protected, Description = 4C617267657374206E756D626572206F662072656769737465727320696E206F6E6520726561642028464320303320616E64203034292E0A
	#tag EndConstant

	#tag Constant, Name = kMaxReadWriteRegisters, Type = Integer, Dynamic = False, Default = \"121", Scope = Protected, Description = 4C617267657374206E756D626572206F6620726567697374657273207772697474656E206279206F6E6520526561642F5772697465204D756C7469706C6520526567697374657273207265717565737420284643203233292E0A
	#tag EndConstant

	#tag Constant, Name = kMaxWriteBits, Type = Integer, Dynamic = False, Default = \"1968", Scope = Protected, Description = 4C617267657374206E756D626572206F6620636F696C7320696E206F6E6520777269746520284643203135292E0A
	#tag EndConstant

	#tag Constant, Name = kMaxWriteRegisters, Type = Integer, Dynamic = False, Default = \"123", Scope = Protected, Description = 4C617267657374206E756D626572206F662072656769737465727320696E206F6E6520777269746520284643203136292E0A
	#tag EndConstant

	#tag Constant, Name = kPrefixCoil, Type = String, Dynamic = False, Default = \"co", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kPrefixDiscreteInput, Type = String, Dynamic = False, Default = \"di", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kPrefixHoldingRegister, Type = String, Dynamic = False, Default = \"hr", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kPrefixInputRegister, Type = String, Dynamic = False, Default = \"ir", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketAddressInUse, Type = String, Dynamic = False, Default = \"Address already in use", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketHostDown, Type = String, Dynamic = False, Default = \"The device is down", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketInvalidPort, Type = String, Dynamic = False, Default = \"Invalid port number", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketLost, Type = String, Dynamic = False, Default = \"Connection closed by the device", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketNetworkUnreachable, Type = String, Dynamic = False, Default = \"Network unreachable", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketNoName, Type = String, Dynamic = False, Default = \"The address could not be resolved", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketNoRoute, Type = String, Dynamic = False, Default = \"No route to the device", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketNoRouteMac, Type = String, Dynamic = False, Default = \"No route to the device. On macOS\x2C also check System Settings > Privacy & Security > Local Network for this app", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketRefused, Type = String, Dynamic = False, Default = \"Connection refused: nothing listens on this port", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kSocketTimedOut, Type = String, Dynamic = False, Default = \"The device did not answer", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kVersion, Type = String, Dynamic = False, Default = \"1.1.0", Scope = Protected, Description = 56657273696F6E206F662074686520564E5320586F6A6F204D6F64627573206C6962726172792E0A
	#tag EndConstant


	#tag Enum, Name = eArea, Type = Integer, Flags = &h1, Description = 54686520666F7572204D6F6462757320646174612061726561732E0A
		Coil
		DiscreteInput
		HoldingRegister
		InputRegister
	#tag EndEnum

	#tag Enum, Name = eConnectionState, Type = Integer, Flags = &h1, Description = 5374617465206F662061204D6F64627573544350436C69656E7420636F6E6E656374696F6E2E0A
		Disconnected
		Connecting
		Connected
	#tag EndEnum

	#tag Enum, Name = eDataType, Type = Integer, Flags = &h1, Description = 486F77207265676973746572732061726520696E7465727072657465642E20426974206973206120636F696C206F7220646973637265746520696E7075743B207468652033322D20616E642036342D626974207479706573207370616E2032206F722034207265676973746572732E0A
		Bit
		Unsigned16
		Signed16
		Unsigned32
		Signed32
		Float32
		Float64
	#tag EndEnum

	#tag Enum, Name = eError, Type = Integer, Flags = &h1, Description = 57687920612072657175657374206661696C6564206F72206120636F6E6E656374696F6E20656E6465642E0A
		None
		NotConnected
		ConnectFailed
		ConnectionLost
		Timeout
		ExceptionResponse
		InvalidResponse
		Cancelled
		InvalidRequest
	#tag EndEnum

	#tag Enum, Name = eFunction, Type = Integer, Flags = &h1, Description = 4D6F646275732066756E6374696F6E20636F64657320737570706F7274656420627920746865206C6962726172792E0A
		ReadCoils = 1
		ReadDiscreteInputs = 2
		ReadHoldingRegisters = 3
		ReadInputRegisters = 4
		WriteSingleCoil = 5
		WriteSingleRegister = 6
		Diagnostics = 8
		WriteMultipleCoils = 15
		WriteMultipleRegisters = 16
		ReportServerID = 17
		MaskWriteRegister = 22
		ReadWriteMultipleRegisters = 23
		EncapsulatedInterface = 43
	#tag EndEnum

	#tag Enum, Name = eWordOrder, Type = Integer, Flags = &h1, Description = 4279746520616E6420776F7264206F72646572206F662076616C756573207370616E6E696E67207365766572616C207265676973746572732E204142434420697320746865204D6F64627573207374616E6461726420286269672D656E6469616E292E0A
		ABCD
		CDAB
		BADC
		DCBA
	#tag EndEnum


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
End Module
#tag EndModule
