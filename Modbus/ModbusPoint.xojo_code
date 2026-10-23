#tag Class
Protected Class ModbusPoint
	#tag Method, Flags = &h21
		Private Function ApplyOption(optionText As String) As Boolean
		  ' A :type or :word order option of a location. False when unknown.
		  Select Case optionText
		  Case kTypeBool, kTypeBit
		    DataType = ModbusTypes.eDataType.Bit
		  Case kTypeUInt16
		    DataType = ModbusTypes.eDataType.Unsigned16
		  Case kTypeInt16
		    DataType = ModbusTypes.eDataType.Signed16
		  Case kTypeUInt32
		    DataType = ModbusTypes.eDataType.Unsigned32
		  Case kTypeInt32
		    DataType = ModbusTypes.eDataType.Signed32
		  Case kTypeFloat32, kTypeFloat
		    DataType = ModbusTypes.eDataType.Float32
		  Case kTypeFloat64, kTypeDouble
		    DataType = ModbusTypes.eDataType.Float64
		  Case kOrderABCD
		    WordOrder = ModbusTypes.eWordOrder.ABCD
		  Case kOrderCDAB
		    WordOrder = ModbusTypes.eWordOrder.CDAB
		  Case kOrderBADC
		    WordOrder = ModbusTypes.eWordOrder.BADC
		  Case kOrderDCBA
		    WordOrder = ModbusTypes.eWordOrder.DCBA
		  Else
		    Return False
		  End Select
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 546865206C6162656C206F66206120636F6465642076616C75653B20656D707479207768656E20697420686173206E6F6E652E0A
		Function EnumLabel(rawValue As Integer) As String
		  If mEnumLabels Is Nil Or Not mEnumLabels.HasKey(rawValue) Then Return ""
		  Return mEnumLabels.Value(rawValue).StringValue
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 546865207261772076616C756573207468617420686176652061206C6162656C3B20696E20617363656E64696E67206F726465722E20456D70747920666F72206120706C61696E206E756D6265722E0A
		Function EnumValues() As Integer()
		  Var values() As Integer
		  If mEnumLabels Is Nil Then Return values
		  For Each key As Variant In mEnumLabels.Keys
		    values.Add(key.IntegerValue)
		  Next
		  values.Sort
		  Return values
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4164647320746865206C6162656C206F66206F6E6520626974206F662061206269746669656C6420726567697374657220286269742030203D206C65617374207369676E69666963616E74292E0A
		Sub AddBitLabel(bit As Integer, label As String)
		  If bit < 0 Or bit > 15 Then Return
		  While BitLabels.LastIndex < bit
		    BitLabels.Add("")
		  Wend
		  BitLabels(bit) = label
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4164647320746865206C6162656C2073686F776E20666F72206F6E65207261772076616C75653B20666F72206578616D706C652030203D2053746F7020616E642031203D2052756E2E0A
		Sub AddEnumLabel(rawValue As Integer, label As String)
		  If mEnumLabels Is Nil Then mEnumLabels = New Dictionary
		  mEnumLabels.Value(rawValue) = label
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 43726561746573206120706F696E742066726F6D2061206C6F636174696F6E2073756368206173206872313038303A696E743136202F20697233303A666C6F617433323A63646162202F20636F35202F206872313038392E342E2052616973657320496E76616C6964417267756D656E74457863657074696F6E2069662069742063616E6E6F7420626520726561642E0A
		Sub Constructor(pointName As String, location As String, factor As Double = 1.0, unitText As String = "")
		  Name = pointName
		  Label = pointName
		  Scale = factor
		  Unit = unitText
		  ParseLocation(location)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 5465787420746F2073686F7720666F72207468652063757272656E742076616C75653A20656E756D206C6162656C202F206269746669656C64206C6162656C73202F206F7220746865207363616C65642076616C756520776974682069747320756E69742E0A
		Function DisplayText() As String
		  If Not HasValue Then Return kTextNoValue
		  If Not IsValid Then Return kTextInvalid

		  Var rawInteger As Integer = RawValue
		  If mEnumLabels <> Nil And mEnumLabels.HasKey(rawInteger) Then
		    Return mEnumLabels.Value(rawInteger).StringValue
		  End If

		  If BitLabels.Count > 0 Then
		    Var parts() As String
		    For bit As Integer = 0 To BitLabels.LastIndex
		      If BitLabels(bit) <> "" And (rawInteger And Bitwise.ShiftLeft(1, bit)) <> 0 Then parts.Add(BitLabels(bit))
		    Next
		    If parts.Count = 0 Then Return kTextNoBitSet
		    Return String.FromArray(parts, kBitSeparator)
		  End If

		  Var text As String = FormattedValue
		  If Unit <> "" Then text = text + " " + Unit
		  Return text
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 436F6E766572747320612076616C756520696E20656E67696E656572696E6720756E69747320696E746F207468652072656769737465727320746F2077726974652E2052616973657320496E76616C6964417267756D656E74457863657074696F6E2069662074686520706F696E7420697320726561642D6F6E6C79206F72207468652076616C7565206973206F757473696465204D696E56616C756520746F204D617856616C75652E0A
		Function EncodeForWrite(newValue As Double) As UInt16()
		  #Pragma BreakOnExceptions Off
		  If Not IsWritable Then Raise New InvalidArgumentException(kErrorNotWritable + " " + Name)
		  If MinValue < MaxValue And (newValue < MinValue Or newValue > MaxValue) Then
		    Raise New InvalidArgumentException(kErrorOutOfRange + " " + Name)
		  End If
		  Var raw As Double = (newValue - ValueOffset) / Scale
		  Return ModbusTypes.EncodeValue(raw, DataType, WordOrder)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 546865207363616C65642076616C756520666F726D6174746564207769746820446563696D616C732064696769747320696E2074686520757365722773206C6F63616C653B20776974686F757420756E69742E0A
		Function FormattedValue() As String
		  Var digits As Integer = Decimals
		  If digits < 0 Then
		    ' Automatic: as many digits as the scale needs (0.1 -> 1; 0.01 -> 2).
		    digits = 0
		    Var resolution As Double = Abs(Scale)
		    While resolution > 0 And resolution < 1 And digits < 6
		      resolution = resolution * 10
		      digits = digits + 1
		    Wend
		  End If

		  Var pattern As String = "0"
		  If digits > 0 Then
		    pattern = pattern + "."
		    For i As Integer = 1 To digits
		      pattern = pattern + "0"
		    Next
		  End If
		  Return Value.ToString(Locale.Current, pattern)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4D61726B732074686520706F696E74206173206E6F7420726561643B20666F72206578616D706C652061667465722061206661696C656420726571756573742E0A
		Sub MarkFailed(message As String)
		  HasValue = False
		  ErrorMessage = message
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub ParseLocation(location As String)
		  #Pragma BreakOnExceptions Off
		  ' location = <area><address>[.<bit>][:<type>][:<word order>]
		  Var trimmed As String = location.Trim
		  Var parts() As String = trimmed.Lowercase.Split(":")
		  Var head As String = parts(0)
		  If head.Length < 3 Then Raise New InvalidArgumentException(kErrorBadLocation + " " + location)

		  Select Case head.Left(2)
		  Case ModbusTypes.kPrefixCoil
		    Area = ModbusTypes.eArea.Coil
		  Case ModbusTypes.kPrefixDiscreteInput
		    Area = ModbusTypes.eArea.DiscreteInput
		  Case ModbusTypes.kPrefixHoldingRegister
		    Area = ModbusTypes.eArea.HoldingRegister
		  Case ModbusTypes.kPrefixInputRegister
		    Area = ModbusTypes.eArea.InputRegister
		  Else
		    Raise New InvalidArgumentException(kErrorBadLocation + " " + location)
		  End Select

		  Var number As String = head.Middle(2)
		  Var dot As Integer = number.IndexOf(".")
		  If dot >= 0 Then
		    Var bitText As String = number.Middle(dot + 1)
		    If Not IsDigits(bitText) Or bitText.ToInteger > 15 Then Raise New InvalidArgumentException(kErrorBadLocation + " " + location)
		    BitIndex = bitText.ToInteger
		    number = number.Left(dot)
		  End If
		  If Not IsDigits(number) Or number.ToInteger > 65535 Then Raise New InvalidArgumentException(kErrorBadLocation + " " + location)
		  Address = number.ToInteger

		  If Area = ModbusTypes.eArea.Coil Or Area = ModbusTypes.eArea.DiscreteInput Or BitIndex >= 0 Then
		    DataType = ModbusTypes.eDataType.Bit
		  Else
		    DataType = ModbusTypes.eDataType.Unsigned16
		  End If

		  ' Unknown options are reported after the loop (a Raise inside a loop ignores the pragma).
		  Var unknownOption As Boolean
		  For i As Integer = 1 To parts.LastIndex
		    If Not ApplyOption(parts(i)) Then
		      unknownOption = True
		      Exit
		    End If
		  Next
		  If unknownOption Then Raise New InvalidArgumentException(kErrorBadLocation + " " + location)

		  ' Coils, discrete inputs and single bits hold one bit: no wider type.
		  If (Area = ModbusTypes.eArea.Coil Or Area = ModbusTypes.eArea.DiscreteInput Or BitIndex >= 0) _
		    And DataType <> ModbusTypes.eDataType.Bit Then
		    Raise New InvalidArgumentException(kErrorBadLocation + " " + location)
		  End If
		  ' A multi-register value must end inside the address space.
		  If Address + RegisterCount > 65536 Then Raise New InvalidArgumentException(kErrorBadLocation + " " + location)
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function IsDigits(text As String) As Boolean
		  If text = "" Then Return False
		  For Each character As String In text.Characters
		    If kDigits.IndexOf(character) < 0 Then Return False
		  Next
		  Return True
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4E756D626572206F662072656769737465727320286F722062697473292074686520706F696E74206F636375706965732E0A
		Function RegisterCount() As Integer
		  If BitIndex >= 0 Or Area = ModbusTypes.eArea.Coil Or Area = ModbusTypes.eArea.DiscreteInput Then Return 1
		  Return ModbusTypes.RegisterCount(DataType)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0, Description = 4465636F6465732074686520706F696E742066726F6D206120626C6F636B206F662072656769737465727320286F7220302F3120626974732920726561642066726F6D20746865206465766963652E20696E6465782069732077686572652074686520706F696E7427732061646472657373207369747320696E2074686520626C6F636B2E0A
		Sub Update(blockValues() As UInt16, index As Integer)
		  Var raw As Double
		  If BitIndex >= 0 Then
		    Var word As Integer = blockValues(index)
		    raw = If((word And Bitwise.ShiftLeft(1, BitIndex)) <> 0, 1, 0)
		  Else
		    raw = ModbusTypes.DecodeValue(blockValues, index, DataType, WordOrder)
		  End If

		  RawValue = raw
		  Value = raw * Scale + ValueOffset
		  IsValid = (InvalidValues.IndexOf(raw) < 0)
		  HasValue = True
		  ErrorMessage = ""
		  LastUpdate = DateTime.Now
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0, Description = 41646472657373206F662074686520706F696E742028302D62617365642070726F746F636F6C2061646472657373292E0A
		Address As Integer
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 436F696C3B20646973637265746520696E7075743B20686F6C64696E67207265676973746572206F7220696E7075742072656769737465722E0A
		Area As ModbusTypes.eArea
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 42697420696E73696465206120726567697374657220283020746F2031352920666F7220706F696E74732073756368206173206872313038392E343B202D31207768656E2074686520706F696E74206973207468652077686F6C652072656769737465722E0A
		BitIndex As Integer = -1
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4C6162656C73206F66207468652062697473206F662061206269746669656C642072656769737465723B2073686F776E20627920446973706C61795465787420666F72207468652062697473207468617420617265207365742E0A
		BitLabels() As String
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46726565207465787420746F2067726F757020706F696E747320696E2061207573657220696E746572666163653B20666F72206578616D706C6520444857206F72204369726375697420312E0A
		Category As String
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 486F7720746865207265676973746572732061726520696E7465727072657465642E0A
		DataType As ModbusTypes.eDataType
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4469676974732061667465722074686520646563696D616C20736570617261746F7220696E20446973706C6179546578743B202D31203D206175746F6D617469632066726F6D205363616C652E0A
		Decimals As Integer = -1
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 57687920746865206C6173742072656164206661696C65643B20656D707479207768656E206974207375636365656465642E0A
		ErrorMessage As String
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 54727565206F6E636520612076616C756520686173206265656E2072656164207375636365737366756C6C792E0A
		HasValue As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 5261772076616C75657320286265666F7265207363616C696E67292074686174206D65616E206E6F20646174613B20666F72206578616D706C65203635353335206F72202D3132372E2054686520706F696E74206973207468656E2073686F776E206173206E6F7420617661696C61626C652E0A
		InvalidValues() As Double
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 46616C7365207768656E20746865207261772076616C7565206973206F6E65206F6620496E76616C696456616C7565732E0A
		IsValid As Boolean
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0, Description = 54727565207768656E20636F6465642076616C7565732068617665206C6162656C73202830203D2053746F703B2031203D2052756EE280A6292E0A
		#tag Getter
			Get
			  Return mEnumLabels <> Nil And mEnumLabels.KeyCount > 0
			End Get
		#tag EndGetter
		HasEnumLabels As Boolean
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0, Description = 54727565207768656E205772697461626C652069732073657420616E642074686520706F696E742063616E206265207772697474656E3A206120636F696C206F7220612077686F6C6520686F6C64696E672072656769737465722E0A
		#tag Getter
			Get
			  If Not Writable Or BitIndex >= 0 Then Return False
			  Return Area = ModbusTypes.eArea.Coil Or Area = ModbusTypes.eArea.HoldingRegister
			End Get
		#tag EndGetter
		IsWritable As Boolean
	#tag EndComputedProperty

	#tag Property, Flags = &h0, Description = 546578742073686F776E20746F2074686520757365723B2064656661756C747320746F204E616D652E0A
		Label As String
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 5768656E207468652076616C756520776173206C61737420726561642E0A
		LastUpdate As DateTime
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4C6172676573742076616C756520616363657074656420627920456E636F6465466F7257726974652028656E67696E656572696E6720756E697473292E204E6F2072616E676520636865636B207768656E204D696E56616C7565203D204D617856616C75652E0A
		MaxValue As Double
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mEnumLabels As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 536D616C6C6573742076616C756520616363657074656420627920456E636F6465466F7257726974652028656E67696E656572696E6720756E697473292E0A
		MinValue As Double
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 556E69717565206B6579206F662074686520706F696E743B2075736564206279204D6F64627573506F6C6C65722E46696E64506F696E7420616E64205772697465506F696E742E0A
		Name As String
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 56616C7565206465636F6465642066726F6D20746865207265676973746572733B206265666F7265205363616C6520616E642056616C75654F66667365742E0A
		RawValue As Double
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 56616C7565203D2052617756616C7565202A205363616C65202B2056616C75654F66667365742E2055736520302E3120666F722061207265676973746572207468617420686F6C64732074656E7468732E0A
		Scale As Double = 1.0
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 467265652076616C756520666F72207468652063616C6C65723B206E6F74207573656420627920746865206C6962726172792E0A
		Tag As Variant
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 556E69742073686F776E206166746572207468652076616C75653B20666F72206578616D706C6520C2B0432E0A
		Unit As String
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 56616C756520696E20656E67696E656572696E6720756E6974732E0A
		Value As Double
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 416464656420746F20746865207363616C65642076616C75652E0A
		ValueOffset As Double
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4F72646572206F6620776F72647320616E6420627974657320666F722033322D20616E642036342D6269742076616C7565732E0A
		WordOrder As ModbusTypes.eWordOrder
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 416C6C6F7773205772697465506F696E74202F20456E636F6465466F725772697465206F6E207468697320706F696E742E0A
		Writable As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0, Description = 4164647265737320746F20777269746520746F207768656E20697420646966666572732066726F6D2074686520616464726573732072656164202864657669636573207769746820736570617261746520736574706F696E7420616E642073746174757320726567697374657273292E202D31203D2073616D6520617320416464726573732E0A
		WriteAddress As Integer = -1
	#tag EndProperty


	#tag Constant, Name = kBitSeparator, Type = String, Dynamic = False, Default = \"\x2C ", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kDigits, Type = String, Dynamic = False, Default = \"0123456789", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kErrorBadLocation, Type = String, Dynamic = False, Default = \"Invalid point location:", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kErrorNotWritable, Type = String, Dynamic = False, Default = \"Point is not writable:", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kErrorOutOfRange, Type = String, Dynamic = False, Default = \"Value out of range for point", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kOrderABCD, Type = String, Dynamic = False, Default = \"abcd", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kOrderBADC, Type = String, Dynamic = False, Default = \"badc", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kOrderCDAB, Type = String, Dynamic = False, Default = \"cdab", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kOrderDCBA, Type = String, Dynamic = False, Default = \"dcba", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTextInvalid, Type = String, Dynamic = False, Default = \"n/a", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kTextNoBitSet, Type = String, Dynamic = False, Default = \"none", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kTextNoValue, Type = String, Dynamic = False, Default = \"\xE2\x80\x94", Scope = Public
	#tag EndConstant

	#tag Constant, Name = kTypeBit, Type = String, Dynamic = False, Default = \"bit", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeBool, Type = String, Dynamic = False, Default = \"bool", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeDouble, Type = String, Dynamic = False, Default = \"double", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeFloat, Type = String, Dynamic = False, Default = \"float", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeFloat32, Type = String, Dynamic = False, Default = \"float32", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeFloat64, Type = String, Dynamic = False, Default = \"float64", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeInt16, Type = String, Dynamic = False, Default = \"int16", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeInt32, Type = String, Dynamic = False, Default = \"int32", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeUInt16, Type = String, Dynamic = False, Default = \"uint16", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kTypeUInt32, Type = String, Dynamic = False, Default = \"uint32", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
	#tag EndViewBehavior
End Class
#tag EndClass
