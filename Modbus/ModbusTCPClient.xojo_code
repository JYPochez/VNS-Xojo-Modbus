#tag Class
Protected Class ModbusTCPClient
Inherits TCPSocket
	#tag Event
		Sub Connected()
		  mConnectTimer.Stop
		  mFailedAttempts = 0
		  mConsecutiveTimeouts = 0
		  mState = ModbusTypes.eConnectionState.Connected
		  mReceiveBuffer = EmptyBytes
		  LastErrorMessage = ""
		  RaiseEvent Connected
		  SendNext
		End Sub
	#tag EndEvent

	#tag Event
		Sub DataAvailable()
		  ' Bytes arrive in arbitrary pieces: accumulate them (without any text encoding) and
		  ' cut out every complete frame, using the length field of the MBAP header.
		  Var incoming As String = ReadAll(Nil)
		  mReceiveBuffer = mReceiveBuffer + incoming

		  Do
		    If mReceiveBuffer.Bytes < 7 Then Return
		    Var buffer As MemoryBlock = mReceiveBuffer
		    buffer.LittleEndian = False
		    Var length As Integer = buffer.UInt16Value(4)
		    If buffer.UInt16Value(2) <> 0 Or length < 2 Or length > 254 Then
		      ' Not Modbus TCP: the stream cannot be resynchronised, so start a new connection.
		      LastErrorMessage = ModbusTypes.kErrorInvalidResponse
		      ConnectionEnded(ModbusTypes.eError.InvalidResponse)
		      Return
		    End If

		    Var total As Integer = 6 + length
		    If buffer.Size < total Then Return
		    Var frame As MemoryBlock = buffer.StringValue(0, total)
		    mReceiveBuffer = buffer.StringValue(total, buffer.Size - total)
		    HandleFrame(frame)

		    ' A handler may have disconnected the client.
		    If mState <> ModbusTypes.eConnectionState.Connected Then Return
		  Loop
		End Sub
	#tag EndEvent

	#tag Event
		Sub Error(err As RuntimeException)
		  ' 102 is raised both for a lost connection and for a peer that closed it.
		  If mState = ModbusTypes.eConnectionState.Disconnected Then Return
		  Var detail As String = err.Message
		  If detail = "" Then detail = ModbusTypes.SocketErrorText(err.ErrorNumber)
		  LastErrorMessage = detail + " (" + err.ErrorNumber.ToString + ")"
		  If mState = ModbusTypes.eConnectionState.Connecting Then
		    ConnectionEnded(ModbusTypes.eError.ConnectFailed)
		  Else
		    ConnectionEnded(ModbusTypes.eError.ConnectionLost)
		  End If
		End Sub
	#tag EndEvent


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

	#tag Method, Flags = &h0, Description = 446973636F6E6E6563747320666F7220676F6F643A206E6F206175746F6D61746963207265636F6E6E656374696F6E3B2070656E64696E67207265717565737473206172652063616E63656C6C65642E2043616C6C2069742066726F6D20746865206F776E6572277320436C6F73696E67206576656E742E0A
		Sub Close()
		  Disconnect
		  mResponseTimer.Stop
		  mConnectTimer.Stop
		  mReconnectTimer.Stop
		  mPaceTimer.Stop
		  Super.Close
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4F70656E732074686520636F6E6E656374696F6E20746F20416464726573733A506F72742E2052657175657374732073656E74207768696C6520646973636F6E6E656374656420616C736F20636F6E6E656374206175746F6D61746963616C6C792E0A
		Sub Connect()
		  mUserDisconnected = False
		  If mState <> ModbusTypes.eConnectionState.Disconnected Then Return
		  mReconnectTimer.Stop

		  If Address.Trim = "" Then
		    LastErrorMessage = ModbusTypes.kErrorNoAddress
		    FailPending(ModbusTypes.eError.NotConnected)
		    Return
		  End If

		  mState = ModbusTypes.eConnectionState.Connecting
		  mReceiveBuffer = EmptyBytes
		  mConnectTimer.StartOnce(ConnectTimeoutMS)
		  Super.Connect
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ConnectionEnded(reason As ModbusTypes.eError)
		  ' Single exit path for every way a connection ends: error, timeout, bad data or Disconnect.
		  mState = ModbusTypes.eConnectionState.Disconnected
		  mConnectTimer.Stop
		  mResponseTimer.Stop
		  mPaceTimer.Stop
		  Super.Close
		  mReceiveBuffer = EmptyBytes

		  RaiseEvent Disconnected(reason)
		  FailPending(reason)

		  ' A handler may already have reconnected (Send or Connect): no second attempt then.
		  If mState <> ModbusTypes.eConnectionState.Disconnected Then Return
		  If AutoReconnect And Not mUserDisconnected And reason <> ModbusTypes.eError.None Then
		    ' The first retry is quick: a connection often fails once right after start-up (on macOS
		    ' while the Local Network permission is being checked) and works at the next attempt.
		    Var delay As Integer = ReconnectDelayMS
		    If mFailedAttempts = 0 Then delay = Min(kFirstRetryDelayMS, ReconnectDelayMS)
		    mFailedAttempts = mFailedAttempts + 1
		    mReconnectTimer.StartOnce(delay)
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 43726561746573206120646973636F6E6E656374656420636C69656E74206F6E20706F7274203530323B207365742041646472657373206265666F72652074686520666972737420726571756573742E0A
		Sub Constructor()
		  Super.Constructor
		  Port = ModbusTypes.kDefaultPort
		  mResponseTimer = New ModbusClientTimer(Self, ModbusClientTimer.eTimerKind.Response)
		  mConnectTimer = New ModbusClientTimer(Self, ModbusClientTimer.eTimerKind.Connect)
		  mReconnectTimer = New ModbusClientTimer(Self, ModbusClientTimer.eTimerKind.Reconnect)
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
		  ' Delivers each request; if a handler raises, the remaining ones are still delivered
		  ' (Finally) before the exception goes on to the caller.
		  If startIndex > requests.LastIndex Then Return
		  Try
		    Deliver(requests(startIndex))
		  Finally
		    DeliverAll(requests, startIndex + 1)
		  End Try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 436C6F7365732074686520636F6E6E656374696F6E20616E642073746F7073206175746F6D61746963207265636F6E6E656374696F6E2E2050656E64696E67207265717565737473206661696C20776974682043616E63656C6C65642E0A
		Sub Disconnect()
		  mUserDisconnected = True
		  mFailedAttempts = 0
		  mReconnectTimer.Stop
		  If mState = ModbusTypes.eConnectionState.Disconnected Then
		    FailPending(ModbusTypes.eError.Cancelled)
		  Else
		    ConnectionEnded(ModbusTypes.eError.None)
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
		Private Sub FailPending(reason As ModbusTypes.eError)
		  ' Fails the request in flight and every queued request, then delivers them.
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
		  If request.SentMicroseconds > 0 Then
		    request.ResponseTimeMS = (System.Microseconds - request.SentMicroseconds) / 1000.0
		  End If
		  If request.ErrorCode = ModbusTypes.eError.Timeout Then
		    mConsecutiveTimeouts = mConsecutiveTimeouts + 1
		  Else
		    mConsecutiveTimeouts = 0
		  End If

		  ' Finally: an exception in the user's handler must not stall the queue.
		  Try
		    Deliver(request)
		  Finally
		    If mState = ModbusTypes.eConnectionState.Connected Then
		      If MaxConsecutiveTimeouts > 0 And mConsecutiveTimeouts >= MaxConsecutiveTimeouts Then
		        ' Many timeouts in a row: the connection is probably half-open (device rebooted,
		        ' cable pulled) although TCP has not noticed. Start a new one.
		        mConsecutiveTimeouts = 0
		        LastErrorMessage = ModbusTypes.kErrorTimeout
		        ConnectionEnded(ModbusTypes.eError.ConnectionLost)
		      ElseIf InterRequestDelayMS > 0 Then
		        mPaceTimer.StartOnce(InterRequestDelayMS)
		      Else
		        SendNext
		      End If
		    End If
		  End Try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub HandleFrame(frame As MemoryBlock)
		  frame.LittleEndian = False
		  Var id As Integer = frame.UInt16Value(0)
		  ' An unknown transaction id is a late answer to a request that already timed out.
		  If mCurrent Is Nil Or id <> mCurrent.TransactionID Then Return

		  mResponseTimer.Stop
		  Var request As ModbusRequest = mCurrent
		  Var pdu As MemoryBlock = frame.StringValue(7, frame.Size - 7)
		  Call request.ParseResponse(pdu)
		  Finish(request)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 496E7465726E616C3A2063616C6C65642062792074686520636C69656E742773206F776E2074696D6572732E20446F206E6F742063616C6C2069742E0A
		Sub HandleTimer(kind As ModbusClientTimer.eTimerKind)
		  Select Case kind
		  Case ModbusClientTimer.eTimerKind.Response
		    If mCurrent <> Nil Then
		      Var request As ModbusRequest = mCurrent
		      request.Fail(ModbusTypes.eError.Timeout)
		      Finish(request)
		    End If

		  Case ModbusClientTimer.eTimerKind.Connect
		    If mState = ModbusTypes.eConnectionState.Connecting Then
		      LastErrorMessage = ModbusTypes.kErrorConnectTimeout
		      ConnectionEnded(ModbusTypes.eError.ConnectFailed)
		    End If

		  Case ModbusClientTimer.eTimerKind.Reconnect
		    If mState = ModbusTypes.eConnectionState.Disconnected And Not mUserDisconnected Then Connect

		  Case ModbusClientTimer.eTimerKind.Pace
		    mPaceTimer.Stop
		    SendNext
		  End Select
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 526561647320636F756E7420636F696C7320284643203031292E2054686520616E73776572206172726976657320696E2052657175657374436F6D706C657465643B206F7220696E2063616C6C6261636B207768656E20676976656E2E0A
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

	#tag Method, Flags = &h0, Description = 517565756573206120726571756573742E2049742069732073656E74207768656E207468652070726576696F7573206F6E6520697320616E7377657265643B2074686520636C69656E7420636F6E6E65637473206669727374206966206E65656465642E0A
		Sub Send(request As ModbusRequest)
		  If request Is Nil Then Return
		  request.IsDone = False
		  request.ErrorCode = ModbusTypes.eError.None
		  request.ErrorMessage = ""
		  request.ExceptionCode = 0

		  If Address.Trim = "" Then
		    request.Fail(ModbusTypes.eError.NotConnected, ModbusTypes.kErrorNoAddress)
		    Deliver(request)
		    Return
		  End If

		  ' Requests connect automatically, except after an explicit Disconnect or Close:
		  ' then only Connect opens the connection again.
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
		  ' One request in flight at a time: Modbus gateways answer in order and many cannot queue.
		  If mState <> ModbusTypes.eConnectionState.Connected Then Return
		  If mCurrent <> Nil Or mQueue.Count = 0 Then Return
		  If mPaceTimer.RunMode <> Timer.RunModes.Off Then Return

		  Var request As ModbusRequest = mQueue(0)
		  mQueue.RemoveAt(0)

		  mLastTransactionID = mLastTransactionID + 1
		  If mLastTransactionID > 65535 Then mLastTransactionID = 1
		  Var frame As MemoryBlock = request.BuildFrame(mLastTransactionID, UnitID)

		  mCurrent = request
		  request.SentMicroseconds = System.Microseconds
		  Write(frame)
		  mResponseTimer.StartOnce(TimeoutMS)
		End Sub
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

	#tag Method, Flags = &h0, Description = 57726974657320636F6E736563757469766520686F6C64696E672072656769737465727320284643203136292E20456163682076616C7565206D75737420626520696E202D333237363820746F20363535333520286E656761746976652076616C756573206172652073656E742061732074776F277320636F6D706C656D656E74292E0A
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


	#tag Hook, Flags = &h0, Description = 54686520636F6E6E656374696F6E20746F2074686520646576696365206973206F70656E2E0A
		Event Connected()
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 54686520636F6E6E656374696F6E20656E6465642E20726561736F6E206973204E6F6E6520616674657220446973636F6E6E6563743B206F746865727769736520436F6E6E6563744661696C6564202F20436F6E6E656374696F6E4C6F7374202F20496E76616C6964526573706F6E73652028736565204C6173744572726F724D657373616765292E0A
		Event Disconnected(reason As ModbusTypes.eError)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 41207265717565737420776974686F75742063616C6C6261636B2077617320616E737765726564207375636365737366756C6C792E0A
		Event RequestCompleted(request As ModbusRequest)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 41207265717565737420776974686F75742063616C6C6261636B206661696C65643A2073656520726571756573742E4572726F72436F646520616E6420726571756573742E4572726F724D6573736167652E0A
		Event RequestFailed(request As ModbusRequest)
	#tag EndHook


	#tag Property, Flags = &h0, Description = 5265636F6E6E656374206175746F6D61746963616C6C792061667465722061206C6F7374206F72206661696C656420636F6E6E656374696F6E2E0A
		AutoReconnect As Boolean = True
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 486F77206C6F6E6720746F207761697420666F722074686520636F6E6E656374696F6E20746F206F70656E3B20696E206D696C6C697365636F6E64732E0A
		ConnectTimeoutMS As Integer = 5000
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 5061757365206265747765656E2074776F2072657175657374733B20696E206D696C6C697365636F6E64732E20536F6D652073657269616C206761746577617973206E656564206120666577206D732E0A
		InterRequestDelayMS As Integer = 0
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 54657874206F6620746865206C61737420636F6E6E656374696F6E206572726F722E0A
		LastErrorMessage As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mConnectTimer As ModbusClientTimer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCurrent As ModbusRequest
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 41667465722074686973206D616E792074696D656F75747320696E206120726F772074686520636F6E6E656374696F6E20697320636F6E73696465726564206C6F737420616E64206F70656E656420616761696E2028612068616C662D6F70656E20636F6E6E656374696F6E206973206E6F7420616C77617973207265706F7274656420627920544350292E2030203D206E657665722E0A
		MaxConsecutiveTimeouts As Integer = 3
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mConsecutiveTimeouts As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mFailedAttempts As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mLastTransactionID As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPaceTimer As ModbusClientTimer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mQueue() As ModbusRequest
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mReceiveBuffer As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mReconnectTimer As ModbusClientTimer
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

	#tag Property, Flags = &h0, Description = 44656C6179206265666F726520616E206175746F6D61746963207265636F6E6E656374696F6E3B20696E206D696C6C697365636F6E64732E0A
		ReconnectDelayMS As Integer = 5000
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 446973636F6E6E65637465643B20436F6E6E656374696E67206F7220436F6E6E65637465642E0A
		#tag Getter
			Get
			  Return mState
			End Get
		#tag EndGetter
		State As ModbusTypes.eConnectionState
	#tag EndComputedProperty

	#tag Property, Flags = &h0, Description = 486F77206C6F6E6720746F207761697420666F72206561636820616E737765723B20696E206D696C6C697365636F6E64732E0A
		TimeoutMS As Integer = 3000
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 44656661756C7420756E69742028736C617665292069643B20757365642062792072657175657374732077686F736520556E69744944206973202D312E204D616E792054435020646576696365732069676E6F72652069743B2073657269616C2067617465776179732075736520697420746F207069636B20746865206465766963652E0A
		UnitID As Integer = 1
	#tag EndProperty


	#tag Constant, Name = kFirstRetryDelayMS, Type = Integer, Dynamic = False, Default = \"1000", Scope = Private, Description = 44656C6179206265666F726520746865206669727374206175746F6D61746963207265636F6E6E656374696F6E3B206C61746572206F6E65732077616974205265636F6E6E65637444656C61794D532E0A
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
			Name="Address"
			Visible=true
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Port"
			Visible=true
			Group="Behavior"
			InitialValue="502"
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
			InitialValue="3000"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="ConnectTimeoutMS"
			Visible=true
			Group="Modbus"
			InitialValue="5000"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="AutoReconnect"
			Visible=true
			Group="Modbus"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="ReconnectDelayMS"
			Visible=true
			Group="Modbus"
			InitialValue="5000"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="MaxConsecutiveTimeouts"
			Visible=true
			Group="Modbus"
			InitialValue="3"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="InterRequestDelayMS"
			Visible=true
			Group="Modbus"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
