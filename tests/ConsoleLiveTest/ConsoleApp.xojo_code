#tag Class
Protected Class ConsoleApp
Inherits ConsoleApplication
	#tag Event
		Function Run(args() as String) As Integer
		  ' 1. Offline checks of the library.
		  Print(kTitleSelfTest)
		  For Each line As String In ModbusSelfTest.Run
		    Print("  " + line)
		  Next

		  ' 2. Live checks against the generic simulator:
		  '    python3 tools/airh2o_simulator.py --mode generic --port 5021
		  Var portNumber As Integer = kDefaultPort
		  If args.Count > 1 Then portNumber = args(1).ToInteger
		  Print(kTitleLive + " " + kDefaultAddress + ":" + portNumber.ToString)

		  Var client As New LiveTestClient
		  client.Address = kDefaultAddress
		  client.Port = portNumber
		  client.AutoReconnect = False
		  client.Start

		  ' A console app has no event loop of its own: keep it turning until every answer is in.
		  Var deadline As Double = System.Microseconds + kTimeoutSeconds * 1000000
		  While Not client.Finished And System.Microseconds < deadline
		    App.DoEvents(10)
		  Wend

		  For Each line As String In client.Report
		    Print("  " + line)
		  Next
		  client.Close

		  If Not client.Finished Then
		    Print(kTimedOut)
		    Return 2
		  End If
		  Var failures As Integer = client.Failures + ModbusSelfTest.FailureCount
		  Print(If(failures = 0, kAllPassed, failures.ToString + " " + kSomeFailed))
		  Return If(failures = 0, 0, 1)
		End Function
	#tag EndEvent


	#tag Constant, Name = kAllPassed, Type = String, Dynamic = False, Default = \"All checks passed.", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kDefaultAddress, Type = String, Dynamic = False, Default = \"127.0.0.1", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kDefaultPort, Type = Integer, Dynamic = False, Default = \"5021", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kSomeFailed, Type = String, Dynamic = False, Default = \"check(s) failed.", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTimedOut, Type = String, Dynamic = False, Default = \"Timed out: is the simulator running?", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTimeoutSeconds, Type = Integer, Dynamic = False, Default = \"20", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTitleLive, Type = String, Dynamic = False, Default = \"Live test against", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTitleSelfTest, Type = String, Dynamic = False, Default = \"Library self-test", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
