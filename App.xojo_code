#tag Class
Protected Class App
Inherits DesktopApplication
	#tag Event
		Sub Opening()
		  ' Library self-test (no device needed): the report goes to the Messages panel.
		  ' Comment it out once it passes; uncomment it after changing the Modbus folder.
		  'RunModbusSelfTest
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h21
		Private Sub RunModbusSelfTest()
		  System.DebugLog(kSelfTestTitle)
		  For Each line As String In ModbusSelfTest.Run
		    System.DebugLog(line)
		  Next
		  
		  ' The airH2O table must parse completely (a bad line raises with its line number).
		  Var airH2O() As ModbusPoint = AirH2OPoints.CreatePoints
		  System.DebugLog(kSelfTestAirH2O + " " + airH2O.Count.ToString)
		End Sub
	#tag EndMethod


	#tag Constant, Name = kEditClear, Type = String, Dynamic = False, Default = \"&Delete", Scope = Public
		#Tag Instance, Platform = Windows, Language = Default, Definition  = \"&Delete"
		#Tag Instance, Platform = Linux, Language = Default, Definition  = \"&Delete"
	#tag EndConstant

	#tag Constant, Name = kFileQuit, Type = String, Dynamic = False, Default = \"&Quit", Scope = Public
		#Tag Instance, Platform = Windows, Language = Default, Definition  = \"E&xit"
	#tag EndConstant

	#tag Constant, Name = kFileQuitShortcut, Type = String, Dynamic = False, Default = \"", Scope = Public
		#Tag Instance, Platform = Mac OS, Language = Default, Definition  = \"Cmd+Q"
		#Tag Instance, Platform = Linux, Language = Default, Definition  = \"Ctrl+Q"
	#tag EndConstant

	#tag Constant, Name = kSelfTestAirH2O, Type = String, Dynamic = False, Default = \"airH2O points parsed:", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kSelfTestTitle, Type = String, Dynamic = False, Default = \"Modbus self-test", Scope = Public
	#tag EndConstant


End Class
#tag EndClass
