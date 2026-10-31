#tag Class
Protected Class RTUSettings
	#tag Method, Flags = &h0, Description = 5265616473207468652073657474696E67732066696C653B206D697373696E67206F7220756E7265616461626C652076616C756573206B6565702074686569722064656661756C74732E0A
		Shared Function Load() As RTUSettings
		  #Pragma BreakOnExceptions Off
		  Var settings As New RTUSettings
		  Var file As FolderItem = SettingsFile(False)
		  If file Is Nil Or Not file.Exists Then Return settings

		  Try
		    Var input As TextInputStream = TextInputStream.Open(file)
		    input.Encoding = Encodings.UTF8
		    Var json As New JSONItem(input.ReadAll)
		    input.Close
		    settings.PortName = json.Lookup(kKeyPort, settings.PortName).StringValue
		    settings.BaudRate = json.Lookup(kKeyBaud, settings.BaudRate).IntegerValue
		    settings.FrameFormat = json.Lookup(kKeyFormat, settings.FrameFormat).StringValue
		    settings.UnitID = json.Lookup(kKeyUnit, settings.UnitID).IntegerValue
		    settings.TimeoutMS = json.Lookup(kKeyTimeout, settings.TimeoutMS).IntegerValue
		    settings.SuppressEcho = json.Lookup(kKeyEcho, settings.SuppressEcho).BooleanValue
		    settings.FunctionCode = json.Lookup(kKeyFunction, settings.FunctionCode).IntegerValue
		    settings.Address = json.Lookup(kKeyAddress, settings.Address).IntegerValue
		    settings.Count = json.Lookup(kKeyCount, settings.Count).IntegerValue
		    settings.Values = json.Lookup(kKeyValues, settings.Values).StringValue
		    settings.WriteAddress = json.Lookup(kKeyWriteAddress, settings.WriteAddress).IntegerValue
		  Catch err As RuntimeException
		    ' A damaged file is ignored: the app starts with the defaults and rewrites it.
		  End Try
		  Return settings
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 577269746573207468652073657474696E67732066696C6520696E20746865206170706C69636174696F6E206461746120666F6C6465722E0A
		Sub Save()
		  #Pragma BreakOnExceptions Off
		  Var file As FolderItem = SettingsFile(True)
		  If file Is Nil Then Return

		  Var json As New JSONItem
		  json.Value(kKeyPort) = PortName
		  json.Value(kKeyBaud) = BaudRate
		  json.Value(kKeyFormat) = FrameFormat
		  json.Value(kKeyUnit) = UnitID
		  json.Value(kKeyTimeout) = TimeoutMS
		  json.Value(kKeyEcho) = SuppressEcho
		  json.Value(kKeyFunction) = FunctionCode
		  json.Value(kKeyAddress) = Address
		  json.Value(kKeyCount) = Count
		  json.Value(kKeyValues) = Values
		  json.Value(kKeyWriteAddress) = WriteAddress
		  json.Compact = False

		  Try
		    Var output As TextOutputStream = TextOutputStream.Create(file)
		    output.Encoding = Encodings.UTF8
		    output.Write(json.ToString)
		    output.Close
		  Catch err As IOException
		    ' Settings are a convenience: failing to save them must not stop the app.
		  End Try
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Shared Function SettingsFile(createFolder As Boolean) As FolderItem
		  #Pragma BreakOnExceptions Off
		  Var folder As FolderItem = SpecialFolder.ApplicationData.Child(kFolderName)
		  If folder Is Nil Then Return Nil
		  If Not folder.Exists Then
		    If Not createFolder Then Return Nil
		    Try
		      folder.CreateFolder
		    Catch err As IOException
		      Return Nil
		    End Try
		    ' An item made before its folder existed stays unusable: resolve it again from its path.
		    folder = New FolderItem(folder.NativePath, FolderItem.PathModes.Native)
		  End If
		  Return folder.Child(kFileName)
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Address As Integer
	#tag EndProperty

	#tag Property, Flags = &h0
		BaudRate As Integer = 19200
	#tag EndProperty

	#tag Property, Flags = &h0
		Count As Integer = 10
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4672616D6520666F726D617420737563682061732038453120286461746120626974733B20706172697479204E2F452F4F3B2073746F702062697473292E0A
		FrameFormat As String = "8E1"
	#tag EndProperty

	#tag Property, Flags = &h0
		FunctionCode As Integer = 3
	#tag EndProperty

	#tag Property, Flags = &h0
		PortName As String
	#tag EndProperty

	#tag Property, Flags = &h0
		SuppressEcho As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		TimeoutMS As Integer = 1000
	#tag EndProperty

	#tag Property, Flags = &h0
		UnitID As Integer = 1
	#tag EndProperty

	#tag Property, Flags = &h0
		Values As String
	#tag EndProperty

	#tag Property, Flags = &h0
		WriteAddress As Integer
	#tag EndProperty


	#tag Constant, Name = kFileName, Type = String, Dynamic = False, Default = \"rtu-settings.json", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kFolderName, Type = String, Dynamic = False, Default = \"VNS Xojo Modbus", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyAddress, Type = String, Dynamic = False, Default = \"address", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyBaud, Type = String, Dynamic = False, Default = \"baudRate", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyCount, Type = String, Dynamic = False, Default = \"count", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyEcho, Type = String, Dynamic = False, Default = \"suppressEcho", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyFormat, Type = String, Dynamic = False, Default = \"format", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyFunction, Type = String, Dynamic = False, Default = \"functionCode", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyPort, Type = String, Dynamic = False, Default = \"portName", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyTimeout, Type = String, Dynamic = False, Default = \"timeoutMS", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyUnit, Type = String, Dynamic = False, Default = \"unitID", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyValues, Type = String, Dynamic = False, Default = \"values", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyWriteAddress, Type = String, Dynamic = False, Default = \"writeAddress", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
