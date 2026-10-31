#tag Class
Protected Class ModbusRTUClient
Inherits SerialConnection
Implements ModbusTransport
	#tag Event
		Sub DataReceived()
		  ' RTU frames have no length field and no transaction id: one request is in flight, and its
		  ' answer ends where the function code and byte count say it ends.
		  Var incoming As String = ReadAll(Nil)
		  If mCurrent Is Nil Then
		    ' Nothing expected: noise or a late answer to a request that timed out.
		    mReceiveBuffer = EmptyBytes
		    Return
		  End If
		  mReceiveBuffer = mReceiveBuffer + incoming

		  Var buffer As MemoryBlock = mReceiveBuffer
		  If mEchoBytes > 0 Then
		    ' Some RS-485 adapters send our own frame back first.
		    If buffer.Size < mEchoBytes Then Return
		    mReceiveBuffer = buffer.StringValue(mEchoBytes, buffer.Size - mEchoBytes)
		    mEchoBytes = 0
		    buffer = mReceiveBuffer
		  End If

		  Var total As Integer = ModbusTypes.RTUResponseLength(buffer, mRequestPDUSize)
		  If total = 0 Then Return
		  If total > 0 And buffer.Size < total Then Return
		  If total < 0 Then total = buffer.Size

		  Var frame As MemoryBlock = buffer.StringValue(0, total)
		  mReceiveBuffer = EmptyBytes
		  RaiseEvent FrameTraced(False, frame)
		  HandleFrame(frame)
		End Sub
	#tag EndEvent

	#tag Event
		Sub Error(e As RuntimeException)
		  If mState = ModbusTypes.eConnectionState.Disconnected Then Return
		  LastErrorMessage = e.Message + " (" + e.ErrorNumber.ToString + ")"
		  Ended(ModbusTypes.eError.ConnectionLost)
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h21
		Private Sub ApplyLineSettings()
		  ' Baud and Bits take Xojo's class constants, not numbers: map the usual rates.
		  Select Case BaudRate
		  Case 1200
		    Baud = SerialConnection.Baud1200
		  Case 2400
		    Baud = SerialConnection.Baud2400
		  Case 4800
		    Baud = SerialConnection.Baud4800
		  Case 9600
		    Baud = SerialConnection.Baud9600
		  Case 14400
		    Baud = SerialConnection.Baud14400
		  Case 19200
		    Baud = SerialConnection.Baud19200
		  Case 38400
		    Baud = SerialConnection.Baud38400
		  Case 57600
		    Baud = SerialConnection.Baud57600
		  Case 115200
		    Baud = SerialConnection.Baud115200
		  Case 230400
		    Baud = SerialConnection.Baud230400
		  Else
		    ' Other rates are passed to the driver as they are (macOS and Windows only).
		    Baud = BaudRate
		  End Select
		  Bits = If(DataBits = 7, SerialConnection.Bits7, SerialConnection.Bits8)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 52656D6F76657320657665727920726571756573742077616974696E6720696E207468652071756575653B2065616368206F6E65206661696C7320776974682043616E63656C6C65642E20546865207265717565737420696E20666C69676874206973206E6F742061666665637465642E0A
		Sub CancelPending()
		  Var cancelled() As ModbusRequest
		  For Each request As ModbusRequest In mQueue
		    cancelled.Add(request)
		  Next
		  mQueue.RemoveAll
		  For Each request As ModbusRequest In cancelled
		    request.Fail(ModbusTypes.eError.Cancelled)
		  Next
		  DeliverAll(cancelled)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 436C6F7365732074686520706F727420666F7220676F6F643A2070656E64696E67207265717565737473206172652063616E63656C6C65642E2043616C6C2069742066726F6D20746865206F776E6572277320436C6F73696E67206576656E742E0A
		Sub Close()
		  Disconnect
		  mResponseTimer.Stop
		  mPaceTimer.Stop
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4F70656E73207468652073657269616C20706F727420506F72744E616D6520776974682042617564526174653B2044617461426974733B2050617269747920616E642053746F704269742E2052657175657374732073656E74207768696C6520636C6F73656420616C736F206F70656E2069742E0A
		Sub Connect()
		  #Pragma BreakOnExceptions Off
		  mUserDisconnected = False
		  If mState = ModbusTypes.eConnectionState.Connected Then Return

		  Var port As SerialDevice
		  Var failure As String
		  Try
		    port = SerialDevice.WithName(PortName)
		  Catch err As RuntimeException
		    port = Nil
		  End Try
		  #Pragma BreakOnExceptions Off
		  If PortName.Trim = "" Or port Is Nil Then failure = ModbusTypes.kErrorNoPort + " " + PortName

		  If failure = "" Then
		    Device = port
		    ApplyLineSettings
		    Try
		      Super.Connect
		    Catch err As IOException
		      failure = err.Message + " (" + err.ErrorNumber.ToString + ")"
		    End Try
		    #Pragma BreakOnExceptions Off
		  End If

		  If failure <> "" Then
		    LastErrorMessage = failure
		    RaiseEvent Disconnected(ModbusTypes.eError.ConnectFailed)
		    FailPending(ModbusTypes.eError.ConnectFailed)
		    Return
		  End If

		  mState = ModbusTypes.eConnectionState.Connected
		  mReceiveBuffer = EmptyBytes
		  LastErrorMessage = ""
		  RaiseEvent Connected
		  SendNext
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor()
		  ' SerialConnection has no constructor of its own to call. Modbus RTU default: 19200 8E1.
		  Parity = SerialConnection.Parities.Even
		  StopBit = SerialConnection.StopBits.One
		  mResponseTimer = New ModbusClientTimer(Self, ModbusClientTimer.eTimerKind.Response)
		  mPaceTimer = New ModbusClientTimer(Self, ModbusClientTimer.eTimerKind.Pace)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Deliver(request As ModbusRequest)
		  ' A request with a callback goes to its callback only; the others raise the events.
		  If request.Callback <> Nil Then
		    Try
		      request.Callback.Invoke(request)
		    Catch err As NilObjectException
		      ' The callback's object no longer exists (WeakAddressOf on a closed window).
		    End Try
		  ElseIf request.Succeeded Then
		    RaiseEvent RequestCompleted(request)
		  Else
		    RaiseEvent RequestFailed(request)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub DeliverAll(requests() As ModbusRequest, startIndex As Integer = 0)
		  ' Delivers each request; if a handler raises, the remaining ones are still delivered.
		  If startIndex > requests.LastIndex Then Return
		  Try
		    Deliver(requests(startIndex))
		  Finally
		    DeliverAll(requests, startIndex + 1)
		  End Try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 436C6F7365732074686520706F72742E2050656E64696E67207265717565737473206661696C20776974682043616E63656C6C65643B206C61746572207265717565737473206661696C20756E74696C20436F6E6E6563742069732063616C6C656420616761696E2E0A
		Sub Disconnect()
		  mUserDisconnected = True
		  If mState = ModbusTypes.eConnectionState.Disconnected Then
		    FailPending(ModbusTypes.eError.Cancelled)
		  Else
		    Ended(ModbusTypes.eError.None)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function EmptyBytes() As String
		  ' An empty string without text encoding; "" would carry UTF-8 into the byte buffer.
		  Var empty As New MemoryBlock(0)
		  Return empty
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Ended(reason As ModbusTypes.eError)
		  mState = ModbusTypes.eConnectionState.Disconnected
		  mResponseTimer.Stop
		  mPaceTimer.Stop
		  Super.Close
		  mReceiveBuffer = EmptyBytes
		  mEchoBytes = 0
		  RaiseEvent Disconnected(reason)
		  FailPending(reason)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub FailPending(reason As ModbusTypes.eError)
		  Var code As ModbusTypes.eError = reason
		  If code = ModbusTypes.eError.None Then code = ModbusTypes.eError.Cancelled

		  Var failed() As ModbusRequest
		  If mCurrent <> Nil Then
		    failed.Add(mCurrent)
		    mCurrent = Nil
		  End If
		  For Each request As ModbusRequest In mQueue
		    failed.Add(request)
		  Next
		  mQueue.RemoveAll

		  For Each request As ModbusRequest In failed
		    request.Fail(code)
		  Next
		  DeliverAll(failed)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Finish(request As ModbusRequest)
		  If mCurrent Is request Then mCurrent = Nil
		  mEchoBytes = 0
		  If request.SentMicroseconds > 0 Then
		    request.ResponseTimeMS = (System.Microseconds - request.SentMicroseconds) / 1000.0
		  End If

		  ' Finally: an exception in the user's handler must not stall the queue.
		  Try
		    Deliver(request)
		  Finally
		    ' The line must stay silent for 3.5 characters between two frames.
		    If mState = ModbusTypes.eConnectionState.Connected Then mPaceTimer.StartOnce(FrameGapMS)
		  End Try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function FrameGapMS() As Integer
		  If InterFrameDelayMS > 0 Then Return InterFrameDelayMS
		  ' 3.5 characters of 11 bits; the specification fixes 1.75 ms above 19200 baud.
		  If BaudRate > 19200 Then Return 2
		  Return Ceiling(3.5 * 11 * 1000 / Max(1, BaudRate))
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub HandleFrame(frame As MemoryBlock)
		  mResponseTimer.Stop
		  Var request As ModbusRequest = mCurrent
		  If request Is Nil Then Return

		  Var expectedCRC As Integer = ModbusTypes.CRC16(frame, frame.Size - 2)
		  Var receivedCRC As Integer = frame.UInt8Value(frame.Size - 2) + frame.UInt8Value(frame.Size - 1) * 256
		  If frame.Size < 5 Or expectedCRC <> receivedCRC Then
		    request.Fail(ModbusTypes.eError.InvalidResponse, ModbusTypes.kErrorCRC)
		  ElseIf frame.UInt8Value(0) <> request.SentUnitID Then
		    request.Fail(ModbusTypes.eError.InvalidResponse, ModbusTypes.kErrorWrongUnit)
		  Else
		    Var pdu As MemoryBlock = frame.StringValue(1, frame.Size - 3)
		    Call request.ParseResponse(pdu)
		  End If
		  Finish(request)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 496E7465726E616C3A2063616C6C65642062792074686520636C69656E742773206F776E2074696D6572732E20446F206E6F742063616C6C2069742E0A
		Sub HandleTimer(kind As ModbusClientTimer.eTimerKind)
		  Select Case kind
		  Case ModbusClientTimer.eTimerKind.Response
		    If mCurrent <> Nil Then
		      Var request As ModbusRequest = mCurrent
		      If request.SentUnitID = 0 Then
		        ' Broadcast: devices never answer; the write is done once it has been sent.
		        request.ErrorCode = ModbusTypes.eError.None
		        request.ErrorMessage = ""
		        request.IsDone = True
		      Else
		        request.Fail(ModbusTypes.eError.Timeout)
		      End If
		      Finish(request)
		    End If

		  Case ModbusClientTimer.eTimerKind.Pace
		    mPaceTimer.Stop
		    SendNext
		  End Select
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4E616D6573206F66207468652073657269616C20706F727473206F66207468697320636F6D70757465723B20666F7220506F72744E616D652E0A
		Shared Function PortNames() As String()
		  Var names() As String
		  For i As Integer = 0 To SerialDevice.LastIndex
		    Var port As SerialDevice = SerialDevice.At(i)
		    names.Add(port.Name)
		  Next
		  Return names
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 53657473206F7220636C656172732062697473206F66206F6E6520686F6C64696E6720726567697374657220696E206F6E65207265717565737420284643203232293A20726573756C74203D202863757272656E7420414E4420616E644D61736B29204F5220286F724D61736B20414E44204E4F5420616E644D61736B292E0A
		Sub MaskWriteRegister(registerAddress As Integer, andMask As Integer, orMask As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  SendNew(ModbusRequest.MaskWrite(registerAddress, andMask, orMask), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 526561647320746865206465766963652773206964656E74696669636174696F6E206F626A6563747320284643203433202F204D4549203134293A2076656E646F723B2070726F6475637420636F64653B207265766973696F6EE280A620696E20726571756573742E4465766963654F626A656374732E0A
		Sub ReadDeviceIdentification(category As Integer = 1, firstObjectID As Integer = 0, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  SendNew(ModbusRequest.ReadDeviceIdentification(category, firstObjectID), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 526561647320746865206465766963652D7370656369666963206964656E74696669636174696F6E206279746573202846432031372920696E746F20726571756573742E526573706F6E736542797465732E2053657269616C2D6C696E652066756E6374696F6E2E0A
		Sub ReportServerID(callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  SendNew(ModbusRequest.ReportServerID, callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4C6F6F706261636B207465737420284643203038202F203030293A20746865206465766963652073656E64732064617461206261636B20756E6368616E6765642E2053657269616C2D6C696E652066756E6374696F6E2E0A
		Sub ReturnQueryData(data As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  SendNew(ModbusRequest.ReturnQueryData(data), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 526561647320636F756E7420636F696C7320284643203031292E0A
		Sub ReadCoils(startAddress As Integer, count As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  SendNew(New ModbusRequest(ModbusTypes.eFunction.ReadCoils, startAddress, count), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 526561647320636F756E7420646973637265746520696E7075747320284643203032292E0A
		Sub ReadDiscreteInputs(startAddress As Integer, count As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  SendNew(New ModbusRequest(ModbusTypes.eFunction.ReadDiscreteInputs, startAddress, count), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 526561647320636F756E7420686F6C64696E672072656769737465727320284643203033292E0A
		Sub ReadHoldingRegisters(startAddress As Integer, count As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  SendNew(New ModbusRequest(ModbusTypes.eFunction.ReadHoldingRegisters, startAddress, count), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 526561647320636F756E7420696E7075742072656769737465727320284643203034292E0A
		Sub ReadInputRegisters(startAddress As Integer, count As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  SendNew(New ModbusRequest(ModbusTypes.eFunction.ReadInputRegisters, startAddress, count), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 57726974657320726567697374657256616C75657320617420777269746541646472657373207468656E2072656164732072656164436F756E74207265676973746572732066726F6D2072656164416464726573733B20696E206F6E65207265717565737420284643203233292E0A
		Sub ReadWriteMultipleRegisters(readAddress As Integer, readCount As Integer, writeAddress As Integer, registerValues() As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  Var words() As UInt16
		  For Each registerValue As Integer In registerValues
		    words.Add(ToRegister(registerValue))
		  Next
		  SendNew(New ModbusRequest(readAddress, readCount, writeAddress, words), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 517565756573206120726571756573742E2049742069732073656E74207768656E207468652070726576696F7573206F6E6520697320616E7377657265643B2074686520706F7274206F70656E73206669727374206966206E65656465642E0A
		Sub Send(request As ModbusRequest)
		  If request Is Nil Then Return
		  request.IsDone = False
		  request.ErrorCode = ModbusTypes.eError.None
		  request.ErrorMessage = ""
		  request.ExceptionCode = 0

		  If mUserDisconnected And mState = ModbusTypes.eConnectionState.Disconnected Then
		    request.Fail(ModbusTypes.eError.NotConnected, ModbusTypes.kErrorDisconnected)
		    Deliver(request)
		    Return
		  End If

		  mQueue.Add(request)
		  If mState = ModbusTypes.eConnectionState.Disconnected Then
		    Connect
		  Else
		    SendNext
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SendNew(request As ModbusRequest, callback As ModbusTypes.RequestCallback, tag As Variant)
		  request.Callback = callback
		  request.Tag = tag
		  Send(request)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SendNext()
		  If mState <> ModbusTypes.eConnectionState.Connected Then Return
		  If mCurrent <> Nil Or mQueue.Count = 0 Then Return
		  If mPaceTimer.RunMode <> Timer.RunModes.Off Then Return

		  Var request As ModbusRequest = mQueue(0)
		  mQueue.RemoveAt(0)
		  Var frame As MemoryBlock = request.BuildRTUFrame(UnitID)

		  If request.SentUnitID = 0 And Not request.IsWrite Then
		    ' Nobody answers a broadcast, so a read cannot be broadcast.
		    request.Fail(ModbusTypes.eError.InvalidRequest, ModbusTypes.kErrorBroadcastRead)
		    Try
		      Deliver(request)
		    Finally
		      SendNext
		    End Try
		    Return
		  End If

		  ' Drop whatever arrived since the last answer, then send.
		  Call ReadAll(Nil)
		  mReceiveBuffer = EmptyBytes
		  mEchoBytes = If(SuppressEcho, frame.Size, 0)
		  mRequestPDUSize = frame.Size - 3
		  mCurrent = request
		  request.SentMicroseconds = System.Microseconds
		  Write(frame)
		  RaiseEvent FrameTraced(True, frame)

		  ' The timeout counts from the end of the transmission.
		  Var transmitMS As Integer = Ceiling(frame.Size * 11 * 1000 / Max(1, BaudRate))
		  If request.SentUnitID = 0 Then
		    mResponseTimer.StartOnce(transmitMS + kBroadcastTurnaroundMS)
		  Else
		    mResponseTimer.StartOnce(transmitMS + TimeoutMS)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ToRegister(registerValue As Integer) As UInt16
		  #Pragma BreakOnExceptions Off
		  If registerValue < -32768 Or registerValue > 65535 Then
		    Raise New InvalidArgumentException(ModbusTypes.kErrorValueOutOfRange)
		  End If
		  If registerValue < 0 Then Return registerValue + 65536
		  Return registerValue
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 57726974657320636F756E7420636F696C7320284643203135292E0A
		Sub WriteMultipleCoils(startAddress As Integer, coilValues() As Boolean, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  Var words() As UInt16
		  For Each coil As Boolean In coilValues
		    words.Add(If(coil, 1, 0))
		  Next
		  SendNew(New ModbusRequest(ModbusTypes.eFunction.WriteMultipleCoils, startAddress, words), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 57726974657320636F6E736563757469766520686F6C64696E672072656769737465727320284643203136292E20456163682076616C7565206D75737420626520696E202D333237363820746F2036353533352E0A
		Sub WriteMultipleRegisters(startAddress As Integer, registerValues() As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  Var words() As UInt16
		  For Each registerValue As Integer In registerValues
		    words.Add(ToRegister(registerValue))
		  Next
		  SendNew(New ModbusRequest(ModbusTypes.eFunction.WriteMultipleRegisters, startAddress, words), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 577269746573206F6E6520636F696C20284643203035292E0A
		Sub WriteSingleCoil(coilAddress As Integer, newValue As Boolean, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  Var words() As UInt16
		  words.Add(If(newValue, 1, 0))
		  SendNew(New ModbusRequest(ModbusTypes.eFunction.WriteSingleCoil, coilAddress, words), callback, tag)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 577269746573206F6E6520686F6C64696E6720726567697374657220284643203036292E206E657756616C7565206D75737420626520696E202D333237363820746F2036353533352E0A
		Sub WriteSingleRegister(registerAddress As Integer, newValue As Integer, callback As ModbusTypes.RequestCallback = Nil, tag As Variant = Nil)
		  Var words() As UInt16
		  words.Add(ToRegister(newValue))
		  SendNew(New ModbusRequest(ModbusTypes.eFunction.WriteSingleRegister, registerAddress, words), callback, tag)
		End Sub
	#tag EndMethod


	#tag Hook, Flags = &h0, Description = 5468652073657269616C20706F7274206973206F70656E2E0A
		Event Connected()
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 54686520706F72742077617320636C6F7365642E20726561736F6E206973204E6F6E6520616674657220446973636F6E6E6563743B206F746865727769736520436F6E6E6563744661696C6564202F20436F6E6E656374696F6E4C6F73742028736565204C6173744572726F724D657373616765292E0A
		Event Disconnected(reason As ModbusTypes.eError)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 41206672616D65207761732073656E74202873656E74203D205472756529206F72207265636569766564202873656E74203D2046616C7365293B20666F72206C6F677320616E642074726F75626C6573686F6F74696E672E0A
		Event FrameTraced(sent As Boolean, frame As MemoryBlock)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 41207265717565737420776974686F75742063616C6C6261636B2077617320616E737765726564207375636365737366756C6C792E0A
		Event RequestCompleted(request As ModbusRequest)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 41207265717565737420776974686F75742063616C6C6261636B206661696C65643A2073656520726571756573742E4572726F72436F646520616E6420726571756573742E4572726F724D6573736167652E0A
		Event RequestFailed(request As ModbusRequest)
	#tag EndHook


	#tag Property, Flags = &h0, Description = 4C696E6520737065656420696E206269747320706572207365636F6E643B20666F72206578616D706C652039363030206F722031393230302028746865204D6F646275732064656661756C74292E0A
		BaudRate As Integer = 19200
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 37206F7220382064617461206269747320284D6F646275732052545520757365732038292E0A
		DataBits As Integer = 8
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 53696C656E6365206265747765656E2074776F206672616D657320696E206D696C6C697365636F6E64733B2030203D206175746F6D617469632028332E352063686172616374657273206174204261756452617465292E0A
		InterFrameDelayMS As Integer = 0
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 54657874206F6620746865206C61737420706F7274206572726F722E0A
		LastErrorMessage As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCurrent As ModbusRequest
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mEchoBytes As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPaceTimer As ModbusClientTimer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mRequestPDUSize As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mQueue() As ModbusRequest
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mReceiveBuffer As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mResponseTimer As ModbusClientTimer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mState As ModbusTypes.eConnectionState
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mUserDisconnected As Boolean
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 4E756D626572206F662072657175657374732077616974696E67206F7220696E20666C696768742E0A
		#tag Getter
			Get
			  If mCurrent Is Nil Then Return mQueue.Count
			  Return mQueue.Count + 1
			End Get
		#tag EndGetter
		PendingCount As Integer
	#tag EndComputedProperty

	#tag Property, Flags = &h0, Description = 4E616D65206F66207468652073657269616C20706F72743B206F6E65206F6620506F72744E616D65732E0A
		PortName As String
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 446973636F6E6E6563746564206F7220436F6E6E65637465642028706F7274206F70656E292E0A
		#tag Getter
			Get
			  Return mState
			End Get
		#tag EndGetter
		State As ModbusTypes.eConnectionState
	#tag EndComputedProperty

	#tag Property, Flags = &h0, Description = 49676E6F72652074686520636F7079206F6620656163682073656E74206672616D65207468617420736F6D652052532D343835206164617074657273206563686F206261636B2E0A
		SuppressEcho As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 486F77206C6F6E6720746F207761697420666F72206561636820616E7377657220616674657220746865206672616D6520686173206265656E2073656E743B20696E206D696C6C697365636F6E64732E0A
		TimeoutMS As Integer = 1000
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 44656661756C7420756E69742028736C61766529206964203120746F203234373B20302062726F616463617374732077726974657320746F2065766572792064657669636520286E6F20616E73776572292E0A
		UnitID As Integer = 1
	#tag EndProperty


	#tag Constant, Name = kBroadcastTurnaroundMS, Type = Integer, Dynamic = False, Default = \"200", Scope = Private, Description = 54696D65206C65667420746F20746865206465766963657320746F2070726F6365737320612062726F616463617374206265666F726520746865206E65787420726571756573742E0A
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
			InitialValue=""
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
			Name="PortName"
			Visible=true
			Group="Modbus"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="BaudRate"
			Visible=true
			Group="Modbus"
			InitialValue="19200"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="DataBits"
			Visible=true
			Group="Modbus"
			InitialValue="8"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="UnitID"
			Visible=true
			Group="Modbus"
			InitialValue="1"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="TimeoutMS"
			Visible=true
			Group="Modbus"
			InitialValue="1000"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="InterFrameDelayMS"
			Visible=true
			Group="Modbus"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="SuppressEcho"
			Visible=true
			Group="Modbus"
			InitialValue="False"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
