local compute_basename_from_title
do
	local special_character_translation_table = {
		["Ä"] = "ae",
		["ä"] = "ae",
		["Ö"] = "oe",
		["ö"] = "oe",
		["Ü"] = "ue",
		["ü"] = "ue",
		["ß"] = "ss",
		["Á"] = "a",
		["á"] = "a",
		["É"] = "e",
		["é"] = "e",
		["Í"] = "i",
		["í"] = "i",
		["Ó"] = "o",
		["ó"] = "o",
		["Ú"] = "u",
		["ú"] = "u",
		["ñ"] = "n"
	}
	
	local utf8_codes = utf8.codes
	local utf8_char = utf8.char
	
	compute_basename_from_title = function( title )
		local basename = ""
		
		for _, code_point in utf8_codes(title) do
			if ( code_point >= 0x61 and code_point <= 0x7A ) or ( code_point >= 0x30 and code_point <= 0x39 ) then
				-- a-z 0-9
				basename = basename .. utf8_char(code_point)
			elseif code_point >= 0x41 and code_point <= 0x5A then
				-- A-Z
				basename = basename .. utf8_char(code_point+32)
			elseif special_character_translation_table[utf8_char(code_point)] then
				basename = basename .. special_character_translation_table[utf8_char(code_point)]
			elseif code_point == 0x20 or code_point == 0x2D then
				-- space or hyphen
				basename = basename .. "_"
			end
		end
		
		return basename
	end
end

local add_img_spec = function(orig, spec, dest)
	local data = orig[spec]
	if data then
		dest[spec] = {
			filename = "../art/" .. spec .. "." .. data.format,
			format = data.format,
			mime_type = data.mimetype,
			width = data.width,
			height = data.height,
			bit_depth = data.bit_depth
		}
	end
end

do
	local errors = false
	
	local log_error = function( message )
		errors = true
		io.stderr:write( "error: " , message , "\n" )
	end
	
	
	local io_open = io.open
	local fd = io_open("disc.json", "r")
	if fd then
		local dkjson_decode = dkjson.decode
		
		local pos
		
		local disc_spec = fd:read("a")
		do
			fd:close()
			
			if disc_spec then
				disc_spec, pos, error_string = dkjson.decode(disc_spec, 1, nil)
				if error_string then
					log_error("couldn't parse disc spec file: " .. error_string)
				end
			else
				log_error("couldn't read disc spec file")
			end
		end
		
		local album_spec, artist_spec
		do
			fd = io_open("../album.json", "r")
			if fd then
				album_spec = fd:read("a")
				
				fd:close()
				
				if album_spec then
					album_spec, pos, error_string = dkjson.decode(album_spec, 1, nil)
					if error_string then
						log_error("couldn't parse album spec file: " .. error_string)
					end
				else
					log_error("couldn't read album spec file")
				end
			else
				log_error("couldn't open album spec file")
			end
			
			fd = io_open("../../artist.json", "r")
			if fd then
				artist_spec = fd:read("a")
				
				fd:close()
				
				if artist_spec then
					artist_spec, pos, error_string = dkjson.decode(artist_spec, 1, nil)
					if error_string then
						log_error("couldn't parse artist spec file: " .. error_string)
					end
				else
					log_error("couldn't read artist spec file")
				end
			else
				log_error("couldn't open artist spec file")
			end
		end
		
		if not errors then
			local totaltracks = #disc_spec.tracks
			
			local metadata = {
				album_artist = artist_spec.name,
				album = album_spec.name,
				disc_number = tonumber(tup.getdirectory()),
				total_tracks = totaltracks,
				artist = artist_spec.name
			}
			
			if album_spec.art then
				local metadata_art = {}
				
				add_img_spec(album_spec.art, "front_cover", metadata_art)
				add_img_spec(album_spec.art, "back_cover", metadata_art)
				
				metadata.art = metadata_art
			end
			
			do
				local tostring = tostring
				local string_format = string.format
				local math_floor = math.floor
				local math_log = math.log
				local encode = encode
				local disc_spec_tracks = disc_spec.tracks
				
				for i = 1, totaltracks do
					local basename = disc_spec_tracks[i].basename or compute_basename_from_title(disc_spec_tracks[i].title)
					local basefilename = string_format("%0" .. tostring(math_floor(math_log(totaltracks, 10) + 1)) .. "u-%s", i, basename)
					
					metadata.title = disc_spec_tracks[i].title
					metadata.track_number = i
					
					encode(basename, basefilename .. ".wav", basefilename, metadata)
				end
			end
			
			--tup.export("LUA_PATH_5_3")
			--tup.definerule{
			--	command="lua53 -e \"dofile('" .. compute_basename_from_title_nodevariable .. "')\" -- " .. album2playlist_xspf_nodevariable .. " " .. extension,
			--	outputs={"album.xspf"}
			--}
		end
	end
end