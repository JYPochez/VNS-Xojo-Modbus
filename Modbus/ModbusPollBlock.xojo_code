#tag Class
Protected Class ModbusPollBlock
	#tag Method, Flags = &h0, Description = 496E7465726E616C3A206F6E6520626C6F636B206F6620636F6E736563757469766520616464726573736573207265616420696E20612073696E676C652072657175657374206279204D6F64627573506F6C6C65722E0A
		Sub Constructor(blockArea As ModbusTypes.eArea, firstAddress As Integer)
		  Area = blockArea
		  StartAddress = firstAddress
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0, Description = 417265612072656164206279207468697320626C6F636B2E0A
		Area As ModbusTypes.eArea
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4E756D626572206F6620726567697374657273206F72206269747320726561642E0A
		Count As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 506F696E7473206465636F6465642066726F6D207468697320626C6F636B2E0A
		Points() As ModbusPoint
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4669727374206164647265737320726561642E0A
		StartAddress As Integer
	#tag EndProperty


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
