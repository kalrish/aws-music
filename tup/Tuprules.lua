tup.include("dkjson.lua")
--tup.include("compute_basename_from_title.lua")

-- album2playlist_xspf_nodevariable = tup.nodevariable("album2playlist-xspf.lua")


local dir_id = string.gsub(tup.getrelativedir(tup.getcwd()), "/", "_")

local escape_string = function(s)
	if s:find(" ") or s:find("|") then
		return "\"" .. s .. "\""
	else
		return s:gsub("%*", "^*")
	end
end

local encoders = {
	["flac"] = function(basename, input_filename, basefilename, metadata)
		local FLAC = tup.getconfig("FLAC")
		if FLAC == "" then
			FLAC = "flac"
		end
		
		local FLAC_FLAGS = tup.getconfig("FLAC_FLAGS_" .. dir_id .. "_" .. basename)
		if FLAC_FLAGS == "" then
			FLAC_FLAGS = tup.getconfig("FLAC_FLAGS_" .. dir_id)
			if FLAC_FLAGS == "" then
				FLAC_FLAGS = tup.getconfig("FLAC_FLAGS")
			end
		end
		
		local arguments = {}
		local arguments_n = 0
		
		if metadata.album then
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "-T"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "ALBUMARTIST=" .. metadata.album_artist
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "-T"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "ALBUM=" .. metadata.album
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "-T"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "DISCNUMBER=" .. tostring(metadata.disc_number)
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "-T"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "TRACKNUMBER=" .. tostring(metadata.track_number)
		end
		
		if metadata.artist then
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "-T"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "ARTIST=" .. metadata.artist
		end
		
		local add_flac_image = function(arguments, picture, image_type)
			local picture_part = "--picture=" .. tostring(image_type) .. "|"
			if picture.mime_type then
				picture_part = picture_part .. picture.mime_type
			end
			picture_part = picture_part .. "||"
			if picture.width and picture.height and picture.bit_depth then
				picture_part = picture_part .. tostring(picture.width) .. "x" .. tostring(picture.height) .. "x" .. tostring(picture.bit_depth)
			end
			picture_part = picture_part .. "|" .. picture.filename
			
			arguments_n = arguments_n + 1
			arguments[arguments_n] = picture_part
		end
		
		if metadata.art then
			if metadata.art.front_cover then
				add_flac_image(arguments, metadata.art.front_cover, 3)
			end
			
			if metadata.art.back_cover then
				add_flac_image(arguments, metadata.art.back_cover, 4)
			end
		end
		
		for i = 1, arguments_n do
			arguments[i] = escape_string(arguments[i])
		end
		
		local output_filename = basefilename .. ".flac"
		
		tup.definerule{
			command=escape_string(FLAC) .. " " .. table.concat(arguments, " ") .. " -T " .. escape_string("TITLE=" .. metadata.title) .. " " .. FLAC_FLAGS .. " -o " .. escape_string(output_filename) .. " -- " .. escape_string(input_filename),
			outputs={output_filename}
		}
	end,
	["lame"] = function(basename, input_filename, basefilename, metadata)
		local LAME = tup.getconfig("LAME")
		if LAME == "" then
			LAME = "lame"
		end
		
		local LAME_FLAGS = tup.getconfig("LAME_FLAGS_" .. dir_id .. "_" .. basename)
		if LAME_FLAGS == "" then
			LAME_FLAGS = tup.getconfig("LAME_FLAGS")
		end
		
		local arguments = {}
		local arguments_n = 0
		
		if metadata.album then
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "--tv"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "TXXX=ALBUM ARTIST=" .. metadata.album_artist
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "--tl"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = metadata.album
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "--tv"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "TPOS=" .. tostring(metadata.disc_number)
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "--tn"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = tostring(metadata.track_number) .. "/" .. tostring(metadata.total_tracks)
		end
		
		if metadata.artist then
			arguments_n = arguments_n + 1
			arguments[arguments_n] = "--ta"
			arguments_n = arguments_n + 1
			arguments[arguments_n] = metadata.artist
		end
		
		local inputs = {}
		
		if metadata.art then
			if metadata.art.front_cover then
				local picture_path
				if metadata.art.front_cover.format == "bmp" then
					local output_image = basefilename .. "-art-" .. tup.base(metadata.art.front_cover.filename) .. ".png"
					tup.definerule{
						command=tup.getconfig("CONVERT") .. " " .. escape_string(metadata.art.front_cover.filename) .. " " .. escape_string(output_image),
						outputs={output_image}
					}
					table.insert(inputs, output_image)
					picture_path = output_image
				else
					picture_path = metadata.art.front_cover.filename
				end
				arguments_n = arguments_n + 1
				arguments[arguments_n] = "--ti"
				arguments_n = arguments_n + 1
				arguments[arguments_n] = picture_path
			end
		end
		
		for i = 1, arguments_n do
			arguments[i] = escape_string(arguments[i])
		end
		
		local output_filename = basefilename .. ".mp3"
		
		tup.definerule{
			inputs=inputs,
			command=escape_string(LAME) .. " " .. table.concat(arguments, " ") .. " --tt " .. escape_string(metadata.title) .. " " .. LAME_FLAGS .. " " .. escape_string(input_filename) .. " " .. escape_string(output_filename),
			outputs={output_filename}
		}
	end,
	["oggenc"] = function(basename, input_filename, basefilename, metadata)
		local album_artist_part
		if metadata.artist then
			album_artist_part = " -a " .. escape_string(metadata.artist)
		else
			album_artist_part = ""
		end
		
		local OGGENC = tup.getconfig("OGGENC")
		if OGGENC == "" then
			OGGENC = "oggenc"
		end
		
		local OGGENC_FLAGS = tup.getconfig("OGGENC_FLAGS_" .. dir_id .. "_" .. basename)
		if OGGENC_FLAGS == "" then
			OGGENC_FLAGS = tup.getconfig("OGGENC_FLAGS")
		end
		
		local output_filename = basename .. ".ogg"
		
		tup.definerule{
			command=escape_string(OGGENC) .. " -t " .. escape_string(metadata.title) .. " -N " .. tostring(metadata.track_number) .. " -c DISCNUMBER=" .. tostring(metadata.disc_number) .. " -l " .. escape_string(metadata.album) .. album_artist_part .. " " .. OGGENC_FLAGS .. " -o " .. escape_string(output_filename) .. " " .. escape_string(input_filename),
			outputs={output_filename}
		}
	end,
	["opusenc"] = function(basename, input_filename, basefilename, metadata)
		local album_artist_part
		if metadata.artist then
			album_artist_part = " --artist " .. escape_string(metadata.artist)
		else
			album_artist_part = ""
		end
		
		local picture_part = ""
		if tup.getconfig("OPUSENC_INCLUDE_ART") ~= "n" then
			if metadata.art then
				if metadata.art.front_cover then
					picture_part = "--picture=3|"
					if metadata.art.front_cover.mime_type then
						picture_part = picture_part .. metadata.art.front_cover.mime_type
					end
					picture_part = picture_part .. "||"
					if metadata.art.front_cover.width then
						picture_part = picture_part .. tostring(metadata.art.front_cover.width) .. "x" .. tostring(metadata.art.front_cover.height) .. "x" .. tostring(metadata.art.front_cover.bit_depth)
					end
					picture_part = picture_part .. "|" .. metadata.art.front_cover.filename
					
					picture_part = escape_string(picture_part)
					picture_part = picture_part .. " "
				end
			end
		end
		
		local OPUSENC = tup.getconfig("OPUSENC")
		if OPUSENC == "" then
			OPUSENC = "opusenc"
		end
		
		local OPUSENC_FLAGS = tup.getconfig("OPUSENC_FLAGS_" .. dir_id .. "_" .. basename)
		if OPUSENC_FLAGS == "" then
			OPUSENC_FLAGS = tup.getconfig("OPUSENC_FLAGS")
		end
		
		local output_filename = basename .. ".ogg"
		
		tup.definerule{
			command=escape_string(OPUSENC) .. " --title " .. escape_string(metadata.title) .. " --comment TRACKNUMBER=" .. tostring(metadata.track_number) .. " --comment DISCNUMBER=" .. tostring(metadata.disc_number) .. " --album " .. escape_string(metadata.album) .. album_artist_part .. " " .. picture_part .. " " .. OPUSENC_FLAGS .. " " .. escape_string(input_filename) .. " " .. escape_string(output_filename),
			outputs={output_filename}
		}
	end
}

local default_encoder = encoders[tup.getconfig("ENCODER")]
encode = function(basename, input_filename, basefilename, metadata)
	local encoder = tup.getconfig("ENCODER_" .. dir_id .. "_" .. basename)
	if encoder == "" then
		encoder = default_encoder
	else
		encoder = encoders[encoder]
	end
	encoder(basename, input_filename, basefilename, metadata)
end

encode = encoders[tup.getconfig("ENCODER")]