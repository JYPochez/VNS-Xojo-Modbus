#tag Class
Protected Class ModbusClientTimer
Inherits Timer
	#tag Event
		Sub Action()
		  ' The owner is held weakly so the client and its timers never keep each other alive.
		  Var owner As ModbusTCPClient
		  If mOwner <> Nil Then owner = ModbusTCPClient(mOwner.Value)
		  If owner Is Nil Then
		    RunMode = Timer.RunModes.Off
		    Return
		  End If
		  owner.HandleTimer(Kind)
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0, Description = 4372656174657320612073746F707065642074696D657220746861742063616C6C73206F776E65722E48616E646C6554696D65722874696D65724B696E6429207768656E2069742066697265732E0A
		Sub Constructor(owner As ModbusTCPClient, timerKind As ModbusClientTimer.eTimerKind)
		  ' Timer has no constructor of its own to call.
		  mOwner = New WeakRef(owner)
		  Kind = timerKind
		  RunMode = Timer.RunModes.Off
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4669726573206F6E63652061667465722064656C61794D53206D696C6C697365636F6E64733B2072657374617274732074686520636F756E74646F776E20696620616C72656164792072756E6E696E672E0A
		Sub StartOnce(delayMS As Integer)
		  Period = Max(1, delayMS)
		  RunMode = Timer.RunModes.Single
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 53746F7073207468652074696D65722E0A
		Sub Stop()
		  RunMode = Timer.RunModes.Off
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0, Description = 5768617420746869732074696D657220697320666F723B20706173736564206261636B20746F2074686520636C69656E742E0A
		Kind As ModbusClientTimer.eTimerKind
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mOwner As WeakRef
	#tag EndProperty


	#tag Enum, Name = eTimerKind, Type = Integer, Flags = &h0, Description = 496E7465726E616C3A20776869636820636C69656E742074696D65722066697265642E0A
		Response
		Connect
		Reconnect
		Pace
	#tag EndEnum


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
