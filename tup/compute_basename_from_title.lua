local special_character_translation_table = {
	["Ä"] = "ae",
	["ä"] = "ae",
	["Ö"] = "oe",
	["ö"] = "oe",
	["Ü"] = "ue",
	["ü"] = "ue"
}

compute_basename_from_title = function( title )
	local basename = ""
	
	for _, code_point in utf8.codes(title) do
		if ( code_point >= 0x61 and code_point <= 0x7A ) or ( code_point >= 0x30 and code_point <= 0x39 ) then
			basename = basename .. utf8.char(code_point)
		elseif code_point >= 0x41 and code_point <= 0x5A then
			basename = basename .. utf8.char(code_point+32)
		elseif special_character_translation_table[utf8.char(code_point)] then
			basename = basename .. special_character_translation_table[utf8.char(code_point)]
		elseif code_point == 0x20 or code_point == 0x2D then
			basename = basename .. "_"
		end
	end
	
	return basename
end