#tag Class
Protected Class AirH2OSettings
	#tag Method, Flags = &h0, Description = 5265616473207468652073657474696E67732066696C653B206D697373696E67206F7220756E7265616461626C652076616C756573206B6565702074686569722064656661756C74732E0A
		Shared Function Load() As AirH2OSettings
		  #Pragma BreakOnExceptions Off
		  Var settings As New AirH2OSettings
		  Var file As FolderItem = SettingsFile(False)
		  If file Is Nil Or Not file.Exists Then Return settings

		  Try
		    Var input As TextInputStream = TextInputStream.Open(file)
		    input.Encoding = Encodings.UTF8
		    Var json As New JSONItem(input.ReadAll)
		    input.Close
		    settings.Address = json.Lookup(kKeyAddress, settings.Address).StringValue
		    settings.Port = json.Lookup(kKeyPort, settings.Port).IntegerValue
		    settings.UnitID = json.Lookup(kKeyUnitID, settings.UnitID).IntegerValue
		    settings.PollPeriodMS = json.Lookup(kKeyPollPeriod, settings.PollPeriodMS).IntegerValue
		    settings.Section = json.Lookup(kKeySection, settings.Section).StringValue
		    settings.WindowWidth = json.Lookup(kKeyWindowWidth, settings.WindowWidth).IntegerValue
		    settings.WindowHeight = json.Lookup(kKeyWindowHeight, settings.WindowHeight).IntegerValue
		  Catch err As RuntimeException
		    ' A damaged file is ignored: the app starts with the defaults and rewrites it on exit.
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
		  json.Value(kKeyAddress) = Address
		  json.Value(kKeyPort) = Port
		  json.Value(kKeyUnitID) = UnitID
		  json.Value(kKeyPollPeriod) = PollPeriodMS
		  json.Value(kKeySection) = Section
		  json.Value(kKeyWindowWidth) = WindowWidth
		  json.Value(kKeyWindowHeight) = WindowHeight
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


	#tag Property, Flags = &h0, Description = 49502061646472657373206F7220686F7374206E616D65206F6620746865204D6F6462757320676174657761792E0A
		Address As String = "127.0.0.1"
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 506F6C6C696E6720706572696F6420696E206D696C6C697365636F6E64732E0A
		PollPeriodMS As Integer = 5000
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4D6F646275732054435020706F72743B2035303230206973207468652073696D756C61746F7220696E20746F6F6C732F2E0A
		Port As Integer = 5020
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4B6579206F66207468652073656374696F6E2073686F776E206C6173742E0A
		Section As String
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4D6F6462757320756E69742069642E0A
		UnitID As Integer = 1
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4D61696E2077696E646F77206865696768743B2030203D2064656661756C742073697A652E0A
		WindowHeight As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4D61696E2077696E646F772077696474683B2030203D2064656661756C742073697A652E0A
		WindowWidth As Integer
	#tag EndProperty


	#tag Constant, Name = kFileName, Type = String, Dynamic = False, Default = \"airh2o-settings.json", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kFolderName, Type = String, Dynamic = False, Default = \"VNS Xojo Modbus", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyAddress, Type = String, Dynamic = False, Default = \"address", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyPollPeriod, Type = String, Dynamic = False, Default = \"pollPeriodMS", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyPort, Type = String, Dynamic = False, Default = \"port", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeySection, Type = String, Dynamic = False, Default = \"section", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyUnitID, Type = String, Dynamic = False, Default = \"unitID", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyWindowHeight, Type = String, Dynamic = False, Default = \"windowHeight", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeyWindowWidth, Type = String, Dynamic = False, Default = \"windowWidth", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
