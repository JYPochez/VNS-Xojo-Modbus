#tag Class
Protected Class ModbusPoller
Inherits Timer
	#tag Event
		Sub Action()
		  PollNow
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = 41646473206120706F696E7420746F20706F6C6C2E20497473204E616D65206D75737420626520756E697175653B206F746865727769736520496E76616C6964417267756D656E74457863657074696F6E206973207261697365642E0A
		Sub AddPoint(newPoint As ModbusPoint)
		  #Pragma BreakOnExceptions Off
		  If newPoint Is Nil Then Return
		  If mIndex Is Nil Then mIndex = New Dictionary
		  If mIndex.HasKey(newPoint.Name) Then
		    Raise New InvalidArgumentException(kErrorDuplicateName + " " + newPoint.Name)
		  End If
		  mPoints.Add(newPoint)
		  mIndex.Value(newPoint.Name) = newPoint
		  mBlocks.RemoveAll
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub BlockDone(request As ModbusRequest)
		  mOutstanding = mOutstanding - 1
		  Var block As ModbusPollBlock = ModbusPollBlock(request.Tag)

		  If request.Succeeded Then
		    For Each p As ModbusPoint In block.Points
		      p.Update(request.Values, p.Address - block.StartAddress)
		    Next
		  Else
		    For Each p As ModbusPoint In block.Points
		      p.MarkFailed(request.ErrorMessage)
		    Next
		    RaiseEvent PollFailed(request)
		  End If

		  If mOutstanding = 0 Then
		    RaiseEvent PointsUpdated
		    If mPollAgain Then
		      mPollAgain = False
		      PollNow
		    End If
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub BuildBlocks()
		  ' Groups the points of each area into as few reads as possible: neighbours closer than
		  ' MaxGap are read together, up to the protocol's limit per request.
		  mBlocks.RemoveAll
		  For areaIndex As Integer = 0 To 3
		    Var area As ModbusTypes.eArea = ModbusTypes.eArea(areaIndex)
		    Var list() As ModbusPoint
		    For Each p As ModbusPoint In mPoints
		      If p.Area = area Then list.Add(p)
		    Next
		    If list.Count = 0 Then Continue
		    list.Sort(AddressOf CompareAddress)

		    Var limit As Integer
		    If area = ModbusTypes.eArea.Coil Or area = ModbusTypes.eArea.DiscreteInput Then
		      limit = ModbusTypes.kMaxReadBits
		    Else
		      limit = Min(MaxBlockRegisters, ModbusTypes.kMaxReadRegisters)
		    End If

		    Var block As ModbusPollBlock
		    For Each p As ModbusPoint In list
		      Var pointEnd As Integer = p.Address + p.RegisterCount
		      If block <> Nil And p.Address <= block.StartAddress + block.Count + MaxGap _
		        And pointEnd - block.StartAddress <= limit Then
		        block.Count = Max(block.Count, pointEnd - block.StartAddress)
		      Else
		        block = New ModbusPollBlock(area, p.Address)
		        block.Count = p.RegisterCount
		        mBlocks.Add(block)
		      End If
		      block.Points.Add(p)
		    Next
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CompareAddress(first As ModbusPoint, second As ModbusPoint) As Integer
		  Return first.Address - second.Address
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 52657475726E732074686520706F696E7420776974682074686973206E616D653B206F72204E696C2E0A
		Function FindPoint(pointName As String) As ModbusPoint
		  If mIndex Is Nil Or Not mIndex.HasKey(pointName) Then Return Nil
		  Return ModbusPoint(mIndex.Value(pointName))
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 416C6C20706F696E747320696E20746865206F72646572207468657920776572652061646465642E0A
		Function Points() As ModbusPoint()
		  Var copy() As ModbusPoint
		  For Each p As ModbusPoint In mPoints
		    copy.Add(p)
		  Next
		  Return copy
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 526561647320657665727920706F696E74206E6F772E20446F6573206E6F7468696E67207768696C65207468652070726576696F757320706F6C6C206973207374696C6C2072756E6E696E672E0A
		Sub PollNow()
		  If Client Is Nil Or mPoints.Count = 0 Then Return
		  If mOutstanding > 0 Then Return
		  ' Rebuilt at every poll (cheap): points, MaxGap or MaxBlockRegisters may have changed.
		  BuildBlocks

		  ' Build every request before counting them: if one cannot be built, the exception leaves
		  ' the poller ready for the next poll instead of waiting for answers that never come.
		  Var requests() As ModbusRequest
		  For Each block As ModbusPollBlock In mBlocks
		    Var request As New ModbusRequest(ModbusTypes.AreaReadFunction(block.Area), block.StartAddress, block.Count)
		    request.Callback = WeakAddressOf BlockDone
		    request.Tag = block
		    requests.Add(request)
		  Next

		  ' Count first: a request may fail at once (no address) and call BlockDone during the loop.
		  mOutstanding = requests.Count
		  For Each request As ModbusRequest In requests
		    Client.Send(request)
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 52656D6F76657320657665727920706F696E742E0A
		Sub RemoveAllPoints()
		  mPoints.RemoveAll
		  mIndex = Nil
		  mBlocks.RemoveAll
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 506F6C6C73206E6F773B207468656E20657665727920506572696F64206D696C6C697365636F6E64732E0A
		Sub Start()
		  PollNow
		  RunMode = Timer.RunModes.Multiple
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 53746F707320706F6C6C696E672E204120706F6C6C20616C72656164792073656E74207374696C6C20636F6D706C657465732E0A
		Sub Stop()
		  RunMode = Timer.RunModes.Off
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub WriteDone(request As ModbusRequest)
		  Var target As ModbusPoint = ModbusPoint(request.Tag)
		  RaiseEvent WriteCompleted(target, request.Succeeded, request.ErrorMessage)
		  If request.Succeeded And RefreshAfterWrite Then
		    If mOutstanding > 0 Then
		      mPollAgain = True
		    Else
		      PollNow
		    End If
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 57726974657320612076616C75652028656E67696E656572696E6720756E6974732920746F2061207772697461626C6520706F696E743B207468656E2072652D726561647320616C6C20706F696E74732E2052616973657320496E76616C6964417267756D656E74457863657074696F6E20666F7220616E20756E6B6E6F776E206F7220726561642D6F6E6C7920706F696E74206F7220612076616C7565206F7574206F662072616E67652E0A
		Sub WritePoint(pointName As String, newValue As Double)
		  #Pragma BreakOnExceptions Off
		  Var target As ModbusPoint = FindPoint(pointName)
		  If target Is Nil Then Raise New InvalidArgumentException(kErrorUnknownPoint + " " + pointName)
		  If Client Is Nil Then Raise New InvalidArgumentException(kErrorNoClient)

		  Var words() As UInt16 = target.EncodeForWrite(newValue)
		  Var writeAt As Integer = If(target.WriteAddress >= 0, target.WriteAddress, target.Address)

		  Var request As ModbusRequest
		  If target.Area = ModbusTypes.eArea.Coil Then
		    request = New ModbusRequest(ModbusTypes.eFunction.WriteSingleCoil, writeAt, words)
		  ElseIf words.Count = 1 And PreferSingleRegisterWrite Then
		    request = New ModbusRequest(ModbusTypes.eFunction.WriteSingleRegister, writeAt, words)
		  Else
		    request = New ModbusRequest(ModbusTypes.eFunction.WriteMultipleRegisters, writeAt, words)
		  End If
		  request.Callback = WeakAddressOf WriteDone
		  request.Tag = target
		  Client.Send(request)
		End Sub
	#tag EndMethod


	#tag Hook, Flags = &h0, Description = 4120626C6F636B20636F756C64206E6F7420626520726561643B2069747320706F696E747320617265206D61726B6564206661696C65642E20726571756573742E4572726F724D6573736167652074656C6C73207768792E0A
		Event PollFailed(request As ModbusRequest)
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 457665727920626C6F636B206F662074686520706F6C6C20686173206265656E20616E73776572656420286F7220686173206661696C6564292E20526561642074686520706F696E747320746F20726566726573682074686520646973706C61792E0A
		Event PointsUpdated()
	#tag EndHook

	#tag Hook, Flags = &h0, Description = 41205772697465506F696E742066696E69736865642E0A
		Event WriteCompleted(target As ModbusPoint, succeeded As Boolean, message As String)
	#tag EndHook


	#tag Property, Flags = &h0, Description = 54686520636F6E6E656374696F6E207573656420746F207265616420616E642077726974653A2061204D6F64627573544350436C69656E74206F722061204D6F64627573525455436C69656E742E0A
		Client As ModbusTransport
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 54727565207768696C65206120706F6C6C2069732077616974696E6720666F7220616E73776572732E0A
		#tag Getter
			Get
			  Return mOutstanding > 0
			End Get
		#tag EndGetter
		IsPolling As Boolean
	#tag EndComputedProperty

	#tag Property, Flags = &h0, Description = 4C617267657374206E756D626572206F66207265676973746572732070657220726561643B206C6F77657220697420666F722064657669636573207468617420726566757365206C6F6E672072656164732E0A
		MaxBlockRegisters As Integer = 125
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4C61726765737420676170206F6620756E7573656420616464726573736573207265616420746F206A6F696E2074776F20706F696E747320696E206F6E6520726571756573742E2030203D206F6E6C792061646A6163656E74206164647265737365732E0A
		MaxGap As Integer = 8
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mBlocks() As ModbusPollBlock
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mIndex As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mOutstanding As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPoints() As ModbusPoint
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mPollAgain As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 5772697465206F6E65207265676973746572207769746820464320303620696E7374656164206F662046432031362E20536F6D652064657669636573202873756368206173207468652048697461636869204154572D4D42532D303229206F6E6C79206163636570742046432030362E0A
		PreferSingleRegisterWrite As Boolean = True
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 506F6C6C20616C6C20706F696E747320616761696E2061667465722061207375636365737366756C2077726974652E0A
		RefreshAfterWrite As Boolean = True
	#tag EndProperty


	#tag Constant, Name = kErrorDuplicateName, Type = String, Dynamic = False, Default = \"A point already has this name:", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kErrorNoClient, Type = String, Dynamic = False, Default = \"ModbusPoller.Client is not set", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kErrorUnknownPoint, Type = String, Dynamic = False, Default = \"Unknown point:", Scope = Public
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
			Name="RunMode"
			Visible=true
			Group="Behavior"
			InitialValue="0"
			Type="RunModes"
			EditorType="Enum"
			#tag EnumValues
				"0 - Off"
				"1 - Single"
				"2 - Multiple"
			#tag EndEnumValues
		#tag EndViewProperty
		#tag ViewProperty
			Name="Period"
			Visible=true
			Group="Behavior"
			InitialValue="5000"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="MaxGap"
			Visible=true
			Group="Modbus"
			InitialValue="8"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="MaxBlockRegisters"
			Visible=true
			Group="Modbus"
			InitialValue="125"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="PreferSingleRegisterWrite"
			Visible=true
			Group="Modbus"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="RefreshAfterWrite"
			Visible=true
			Group="Modbus"
			InitialValue="True"
			Type="Boolean"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
