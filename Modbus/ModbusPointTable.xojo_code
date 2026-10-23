#tag Module
Protected Module ModbusPointTable
	#tag Method, Flags = &h21
		Private Sub ApplyLabels(target As ModbusPoint, labels As String, translator As ModbusPointTable.Translator)
		  ' labels: "0=Stop|1=Run" for coded values; "b0=Defrost|b5=Compressor" for bits
		  If labels = "" Then Return
		  For Each entry As String In labels.Split(kListSeparator)
		    Var equalPosition As Integer = entry.IndexOf(kKeySeparator)
		    If equalPosition < 1 Then Continue
		    Var key As String = entry.Left(equalPosition).Trim
		    Var text As String = TranslateText(entry.Middle(equalPosition + 1).Trim, translator)
		    If key.Left(1) = kBitPrefix Then
		      target.AddBitLabel(key.Middle(1).ToInteger, text)
		    Else
		      target.AddEnumLabel(key.ToInteger, text)
		    End If
		  Next
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function Field(fields() As String, index As Integer) As String
		  If index > fields.LastIndex Then Return ""
		  Return fields(index).Trim
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function NumberField(fields() As String, index As Integer, defaultValue As Double) As Double
		  ' Numbers in the table always use a dot as decimal separator, whatever the user's locale.
		  Var text As String = Field(fields, index)
		  If text = "" Then Return defaultValue
		  Return Double.FromString(text, Locale.Raw)
		End Function
	#tag EndMethod

	#tag Method, Flags = &h1, Description = 437265617465732074686520706F696E7473206465736372696265642062792061207461626C653A206F6E6520706F696E7420706572206C696E652E2053656520746865206D6F64756C65206E6F74657320666F722074686520636F6C756D6E732E207472616E736C61746F7220286F7074696F6E616C29207472616E736C61746573206576657279206C6162656C2073686F776E20746F2074686520757365722E0A
		Protected Function Parse(table As String, translator As ModbusPointTable.Translator = Nil) As ModbusPoint()
		  #Pragma BreakOnExceptions Off
		  Var points() As ModbusPoint
		  Var lines() As String = table.ReplaceLineEndings(EndOfLine.UNIX).Split(EndOfLine.UNIX)
		  For lineIndex As Integer = 0 To lines.LastIndex
		    Var line As String = lines(lineIndex).Trim
		    If line = "" Or line.Left(1) = kCommentPrefix Then Continue
		    points.Add(ParseLine(line, lineIndex + 1, translator))
		  Next
		  Return points
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseLine(line As String, lineNumber As Integer, translator As ModbusPointTable.Translator) As ModbusPoint
		  ' One table line -> one point.
		  #Pragma BreakOnExceptions Off
		  Var fields() As String = line.Split(kFieldSeparator)
		  If fields.Count < 2 Then Raise New InvalidArgumentException(kErrorLine + " " + lineNumber.ToString)
		  
		  Var p As ModbusPoint
		  Var failure As String
		  Try
		    p = New ModbusPoint(Field(fields, 0), Field(fields, 1), NumberField(fields, 2, 1.0), Field(fields, 3))
		  Catch err As InvalidArgumentException
		    failure = err.Message
		  End Try
		  ' Repeated on purpose: after a caught exception the pragma no longer applied to the Raise below.
		  #Pragma BreakOnExceptions Off
		  If p Is Nil Then Raise New InvalidArgumentException(kErrorLine + " " + lineNumber.ToString + ": " + failure)
		  
		  p.Category = TranslateText(Field(fields, 4), translator)
		  Var label As String = Field(fields, 5)
		  If label <> "" Then p.Label = TranslateText(label, translator)
		  p.Writable = (Field(fields, 6) = kAccessWrite)
		  p.MinValue = NumberField(fields, 7, 0)
		  p.MaxValue = NumberField(fields, 8, 0)
		  ApplyLabels(p, Field(fields, 9), translator)
		  
		  Var invalid As String = Field(fields, 10)
		  If invalid <> "" Then
		    For Each item As String In invalid.Split(kListSeparator)
		      p.InvalidValues.Add(Double.FromString(item.Trim, Locale.Raw))
		    Next
		  End If
		  
		  If Field(fields, 11) <> "" Then p.Decimals = Field(fields, 11).ToInteger
		  Return p
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function TranslateText(text As String, translator As ModbusPointTable.Translator) As String
		  If translator Is Nil Or text = "" Then Return text
		  Return translator.Invoke(text)
		End Function
	#tag EndMethod


	#tag DelegateDeclaration, Flags = &h1, Description = 52657475726E7320746865207465787420746F2073686F7720666F7220616E20456E676C697368206C6162656C2066726F6D20746865207461626C653B20666F72206578616D706C6520697473207472616E736C6174696F6E2E0A
		Protected Delegate Function Translator(text As String) As String
	#tag EndDelegateDeclaration


	#tag Note, Name = Table format
		One point per line; fields separated by semicolons; empty lines and lines starting with # are ignored.

		 0 name       unique key, e.g. dhw.temp
		 1 location   area + address [+ .bit] [:type] [:word order], e.g. hr1080:int16
		 2 scale      value = raw * scale (empty = 1); dot as decimal separator
		 3 unit       e.g. °C
		 4 category   free grouping text, e.g. DHW
		 5 label      text shown to the user (empty = name)
		 6 access     R = read only, W = writable
		 7 min        smallest value accepted by a write (engineering units)
		 8 max        largest value accepted by a write
		 9 labels     coded values 0=Stop|1=Run, or bits b0=Defrost|b5=Compressor
		10 invalid    raw values meaning "no data", e.g. -127|-67|65535
		11 decimals   digits shown (empty = automatic from scale)

		Example:
		dhw.temp;hr1080:int16;1;°C;DHW;DHW temperature;R;;;;-127|-67
		dhw.setpoint;hr1025;1;°C;DHW;DHW setpoint;W;30;60
	#tag EndNote


	#tag Constant, Name = kAccessWrite, Type = String, Dynamic = False, Default = \"W", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kBitPrefix, Type = String, Dynamic = False, Default = \"b", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kCommentPrefix, Type = String, Dynamic = False, Default = \"#", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kErrorLine, Type = String, Dynamic = False, Default = \"Invalid point table line", Scope = Protected
	#tag EndConstant

	#tag Constant, Name = kFieldSeparator, Type = String, Dynamic = False, Default = \";", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kKeySeparator, Type = String, Dynamic = False, Default = \"\x3D", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kListSeparator, Type = String, Dynamic = False, Default = \"|", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
	#tag EndViewBehavior
End Module
#tag EndModule
