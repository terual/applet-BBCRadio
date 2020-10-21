-- BBC Radio applet - plays FlashAAC/MP3 and WMA versions of BBC Radio Live and Listen Again streams
--
-- Allows Squeezeplay players connected to MySqueezebox.com to play BBC Radio streams without requring
-- a local server and server plugin
--
-- Copyright (c) 2010, Adrian Smith, (Triode) triode1@btinternet.com
--
-- Released under the BSD license for use with the Logitech Squeezeplay application

local next, pairs, ipairs, type, package, string, tostring, pcall, math = next, pairs, ipairs, type, package, string, tostring, pcall, math

local oo               = require("loop.simple")
local debug            = require("jive.utils.debug")

local mime             = require("mime")
local lxp              = require("lxp")
local os               = require("os")

local Applet           = require("jive.Applet")

local RequestHttp      = require("jive.net.RequestHttp")
local SocketHttp       = require("jive.net.SocketHttp")

local Framework        = require("jive.ui.Framework")
local Window           = require("jive.ui.Window")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Checkbox         = require("jive.ui.Checkbox")
local Task             = require("jive.ui.Task")
local Player           = require("jive.slim.Player")

local socketurl        = require("socket.url")
local dns              = require("jive.net.DNS")

local appletManager    = appletManager
local jnt              = jnt


module(..., Framework.constants)
oo.class(_M, Applet)

local live_prefix = "http://www.bbc.co.uk/mediaselector/4/mtis/stream/"
local la_prefix   = "http://www.bbc.co.uk/radio/aod/availability/"
local img_prefix  = "http://www.bbc.co.uk/iplayer/img/"
local img_templ   = "http://node1.bbcimg.co.uk/iplayer/images/episode/%s_512_288.jpg";

local live = {
	{ text = "BBC Radio 1",       id = "bbc_radio_one",     img = "radio/bbc_radio_one.gif"    },
	{ text = "BBC Radio 1Xtra",   id = "bbc_1xtra",         img = "radio/bbc_radio_two.gif"    },
	{ text = "BBC Radio 2",       id = "bbc_radio_two",     img = "radio/bbc_radio_two.gif"    },
	{ text = "BBC Radio 3",       id = "bbc_radio_three",   img = "radio/bbc_radio_three.gif"  },
	{ text = "BBC Radio 4 FM",    id = "bbc_radio_fourfm",  img = "radio/bbc_radio_four.gif"   },
	{ text = "BBC Radio 4 LW",    id = "bbc_radio_fourlw",  img = "radio/bbc_radio_four.gif"   },
	{ text = "BBC Radio 5 Live",  id = "bbc_radio_five_live", img = "radio/bbc_radio_five_live.gif" },
	{ text = "BBC Radio 5 Sports",id = "bbc_radio_five_live_sports_extra", img = "radio/bbc_radio_five_live_sports_extra.gif" },
	{ text = "BBC Radio 6 Music", id = "bbc_6music",        img = "radio/bbc_6music.gif"       },
	{ text = "BBC Radio 7",       id = "bbc_7",             img = "radio/bbc_7.gif"            },
	{ text = "BBC Asian Network", id = "bbc_asian_network", img = "radio/bbc_asian_network.gif" },
	{ text = "BBC World Service", id = "bbc_world_service", img = "radio/bbc_world_service.gif" },
	{ text = "BBC Radio Scotland",id = "bbc_radio_scotland",img = "radio/bbc_radio_scotland_1.gif" },
	{ text = "BBC Radio nan Gaidheal", id = "bbc_radio_nan_gaidheal", img = "radio/bbc_radio_nan_gaidheal.gif" },
	{ text = "BBC Radio Ulster",  id = "bbc_radio_ulster",  img = "radio/bbc_radio_ulster.gif" },
	{ text = "BBC Radio Foyle",   id = "bbc_radio_foyle",   img = "station_logos/bbc_radio_foyle.png" },
	{ text = "BBC Radio Wales",   id = "bbc_radio_wales",   img = "radio/bbc_radio_wales.gif" },
	{ text = "BBC Radio Cymru",   id = "bbc_radio_cymru",   img = "radio/bbc_radio_cymru.gif" },
}

local listenagain = {
	{ text = "BBC Radio 1",       id = "radio1.xml",      },
	{ text = "BBC Radio 1Xtra",   id = "1xtra.xml",       },
	{ text = "BBC Radio 2",       id = "radio2.xml",      },
	{ text = "BBC Radio 3",       id = "radio3.xml",      },
	{ text = "BBC Radio 4 FM",    id = "radio4.xml",      service = "bbc_radio_fourfm" },
	{ text = "BBC Radio 4 LW",    id = "radio4.xml",      service = "bbc_radio_fourlw" },
	{ text = "BBC Radio 5 Live",  id = "fivelive.xml",    },
	{ text = "BBC Radio 6 Music", id = "6music.xml",      },
	{ text = "BBC Radio 7",       id = "bbc7.xml",        },
	{ text = "BBC Asian Network", id = "asiannetwork.xml" },
	{ text = "BBC World Service", id = "worldservice.xml" },
	{ text = "BBC Radio Scotland",id = "radioscotland.xml"},
	{ text = "BBC Radio nan Gaidheal", id = "alba.xml"    },
	{ text = "BBC Radio Ulster",  id = "radioulster.xml"  },
	{ text = "BBC Radio Wales",   id = "radiowales.xml"   },
	{ text = "BBC Radio Cymru",   id = "radiocymru.xml"   }
}

local localradio = {
	{ text = "BBC Berkshire",     id = "bbc_radio_berkshire" },
	{ text = "BBC Bristol",       id = "bbc_radio_bristol"   },
	{ text = "BBC Cambridgeshire",id = "bbc_radio_cambridge" },
	{ text = "BBC Cornwall",      id = "bbc_radio_cornwall"  },
	{ text = "BBC Coventry & Warwickshire", id = "bbc_radio_coventry_warwickshire" },
	{ text = "BBC Cumbria",       id = "bbc_radio_cumbria"   },
	{ text = "BBC Derby",         id = "bbc_radio_derby"     },
	{ text = "BBC Devon",         id = "bbc_radio_devon"     },
	{ text = "BBC Essex",         id = "bbc_radio_essex"     },
	{ text = "BBC Gloucestershire", id = "bbc_radio_gloucestershire" },
	{ text = "BBC Guernsey",      id = "bbc_radio_guernsey"  },
	{ text = "BBC Hereford & Worcester", id = "bbc_radio_hereford_worcester" },
	{ text = "BBC Humberside",    id = "bbc_radio_humberside" },
	{ text = "BBC Jersey",        id = "bbc_radio_jersey"    },
	{ text = "BBC Kent",          id = "bbc_radio_kent"      },
	{ text = "BBC Lancashire",    id = "bbc_radio_lancashire" },
	{ text = "BBC Leeds",         id = "bbc_radio_leeds" },
	{ text = "BBC Leicester",     id = "bbc_radio_leicester" },
	{ text = "BBC Lincolnshire",  id = "bbc_radio_lincolnshire" },
	{ text = "BBC London",        id = "bbc_london"          },
	{ text = "BBC Manchester",    id = "bbc_radio_manchester" },
	{ text = "BBC Merseyside",    id = "bbc_radio_merseyside" },
	{ text = "BBC Newcastle",     id = "bbc_radio_newcastle" },
	{ text = "BBC Norfolk",       id = "bbc_radio_norfolk"   },
	{ text = "BBC Northampton",   id = "bbc_radio_northampton" },
	{ text = "BBC Nottingham",    id = "bbc_radio_nottingham" },
	{ text = "BBC Oxford",        id = "bbc_radio_oxford"     },
	{ text = "BBC Sheffield",     id = "bbc_radio_sheffield"  },
	{ text = "BBC Shropshire",    id = "bbc_radio_shropshire" },
	{ text = "BBC Solent",        id = "bbc_radio_solent"     },
	{ text = "BBC Somerset",      id = "bbc_radio_somerset_sound" },
	{ text = "BBC Stoke",         id = "bbc_radio_stoke"      },
	{ text = "BBC Suffolk",       id = "bbc_radio_suffolk"    },
	{ text = "BBC Surrey",        id = "bbc_radio_surrey"     },
	{ text = "BBC Sussex",        id = "bbc_radio_sussex"     },
	{ text = "BBC Tees",          id = "bbc_tees"             },
	{ text = "BBC Three Counties",id = "bbc_three_counties_radio" },
	{ text = "BBC Wiltshire",     id = "bbc_radio_wiltshire"  },
	{ text = "BBC WM",            id = "bbc_wm"               },
	{ text = "BBC York",          id = "bbc_radio_york"       },
}


local tzoffset = os.time(os.date("*t")) - os.time(os.date("!*t"))

function str2timeZ(timestr)
	local year, mon, mday, hour, min, sec = string.match(timestr, "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")
	return os.time({ hour = hour, min = min, sec = sec, year = year, month = mon, day = mday }) + tzoffset
end


function menu(self, menuItem)
	local window = Window("text_list", menuItem.text)
	local menu   = SimpleMenu("menu")

	-- listen live menus
	menu:addItem({
		text = "Listen Live",
		sound = "WINDOWSHOW",
		callback = function(_, menuItem)
			local window = Window("text_list", menuItem.text)
			local menu   = SimpleMenu("menu")
			for _, entry in pairs(live) do
				menu:addItem({
					text = entry.text,
					isPlayableItem = 1,
					style = 'item_choice',
					callback = function()
						self:_play({ url = live_prefix .. entry.id, title = entry.text, img = img_prefix .. entry.img })
						appletManager:callService('goNowPlaying', Window.transitionPushLeft, false)
					end,
				})
			end
			for _, entry in pairs(localradio) do
				menu:addItem({
					text = entry.text,
					isPlayableItem = 1,
					style = 'item_choice',
					callback = function()
						self:_play({ url = live_prefix .. entry.id, title = entry.text })
						appletManager:callService('goNowPlaying', Window.transitionPushLeft, false)
					end,
				})
			end
			window:addWidget(menu)
			self:tieAndShowWindow(window)
		end
	})

	-- listen again menus - fetch the xml and parse into a menu as it is received
	for _, entry in pairs(listenagain) do
		menu:addItem({
			text = entry.text,
			sound = "WINDOWSHOW",
			callback = function(_, menuItem)
				local url = la_prefix .. entry.id
				log:info("fetching: ", url)
				local req = RequestHttp(self:_sink(menu, menuItem.text, entry.service), 'GET', url, { stream = true })
				local uri = req:getURI()
				local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
				http:fetch(req)
			end,
		})
	end
	for _, entry in pairs(localradio) do
		menu:addItem({
			text = entry.text,
			sound = "WINDOWSHOW",
			callback = function(_, menuItem)
				local url = la_prefix .. entry.id .. ".xml"
				log:info("fetching: ", url)
				local req = RequestHttp(self:_sink(menu, menuItem.text, entry.service), 'GET', url, { stream = true })
				local uri = req:getURI()
				local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
				http:fetch(req)
			end,
		})
	end

	-- add setting for wma vs rtmp streams
	menu:addItem({
		text = "WMA streams",
		style = 'item_choice',
		check = Checkbox("checkbox",
			function(object, isSelected)
				self:getSettings()["usewma"] = isSelected
				self:storeSettings()
			end,
			self:getSettings()["usewma"]
		),
	})

	window:addWidget(menu)
	self:tieAndShowWindow(window)
end


function _sink(self, prevmenu, title, service)
	local window = Window("text_list", title)
	local menu   = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)
	prevmenu:lock()

	local submenus = {}
	local entry
	local capture
	local now = os.time()
	local today = os.date("*t").day
	local pos = 10

	local p = lxp.new({
		StartElement = function (parser, name, attr)
			capture = nil			   
			if name == "entry" then
				entry = { epid = attr.pid }
			elseif name == "title" or name == "pid" or name == "service" or name == "title" or name == "synopsis" or name == "link" then
				capture = name
			elseif name == "parent" then
				capture = string.lower(attr.type)
			elseif name == "broadcast" then
				entry.bcast = str2timeZ(attr["start"])
				entry.dur   = attr["duration"]
			elseif name == "availability" then
				entry.astart = str2timeZ(attr["start"])
				entry.aend   = str2timeZ(attr["end"])
			end
		end,
		CharacterData = function (parser, string)
			if entry and capture and string.match(string, "%w") then
				entry[capture] = (entry[capture] or "") .. string
			end
		end,
		EndElement = function (parser, name)
			if name == "entry" then
				if service and service ~= entry.service then
					log:debug("wrong service (", entry.service, " != ", service, ")")
					return
				end
				if entry.astart > now or entry.aend < now then
					log:debug("not available (", entry.astart, " - ", entry.aend, " outside ", now, ")")
					return
				end

				local submenu
				local date = os.date("*t", entry.bcast)
				local title = string.match(entry.title, "(.-), %d+%/%d+%/%d") or entry.title
				if submenus[date.day] then
					submenu = submenus[date.day]
				else
					submenu = SimpleMenu("menu")
					submenus[date.day] = submenu

					menu:addItem({
						text = date.day == today and "Today" or os.date("%A", entry.bcast),
						sound = "WINDOWSHOW",
						weight = pos,
						callback = function(_, menuItem)
							local window = Window("text_list", menuItem.text)
							window:addWidget(submenu)
							self:tieAndShowWindow(window)
						end
					})
					pos = pos - 1
				end
				local url, desc, pid, dur = entry.link, entry.synopsis, entry.pid, entry.dur
				submenu:addItem({
					text = string.format("%02d:%02d %s", date.hour, date.min, title),
					isPlayableItem = 1,
					style = 'item_choice',
					callback = function()
						self:_play({ url = url, title = title, desc = desc, img = string.format(img_templ, pid), dur = dur })
						appletManager:callService('goNowPlaying', Window.transitionPushLeft, false)
					end,
					weight = 2
				})
			end
		end
	})

	return function(chunk)
		if chunk == nil then
			p:parse()
			p:close()
			prevmenu:unlock()
			self:tieAndShowWindow(window)
			return
		else
			p:parse(chunk)
		end
	end
end


function _play(self, stream)
	local player = Player:getLocalPlayer()
	local server = player and player:getSlimServer()

	local url = "spdr://bbcmsparser?url=" .. mime.b64(stream.url)
	if stream.img then
		url = url .. "&icon=" .. mime.b64(stream.img)
	end
	if stream.desc then
		url = url .. "&artist=" .. mime.b64(stream.desc)
	end
	if stream.dur then
		url = url .. "&dur=" .. mime.b64(stream.dur)
	end
	log:info("sending request to ", server, " player ", player, " url ", url)
	server:userRequest(nil,	player:getId(), { "playlist", "play", url, stream.title })
end


------------------------------------------------------
-- code below is the protocol handler for playing streams via spdr:// urls

-- protocol handler registered in meta - fetch the mediaselector xml
function bbcmsparser(self, playback, data, decode)
	local cmdstr = playback.header .. "&"			   
	local url = string.match(cmdstr, "url%=(.-)%&")
	url = mime.unb64("", url)
	log:info("url: ", url)

	data.start = string.match(cmdstr, "start%=(.-)%&")
	if data.start then
		data.start = mime.unb64("", data.start)
		log:info("start: ", data.start)
	end
	
	local req = RequestHttp(_sinkMSParser(self, playback, data, decode), 'GET', url, {})
	local uri = req:getURI()
	local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
	http:fetch(req)
end


-- sink to parse mediaselector xml
function _sinkMSParser(self, playback, data, decode)
	local services = {}
	local service
	local p = lxp.new({
		StartElement = function (parser, name, attr)
			if name == "media" and attr.service then
				service = attr.service
			elseif name == "connection" and service then
				services[service] = attr
			end
		end,
	})

	return function(content)
		if content == nil then
			p:parse()
			p:close()
			local entry
			for s in self:preferredServices() do
				if services[s] then
					entry = services[s]
					entry["service"] = s
					break
				end
			end
			if string.match(entry["service"], "stream_aac") or string.match(entry["service"], "stream_mp3") then
				log:info("rtmp: ", entry["service"])
				self:_playstreamRTMP(playback, data, decode, entry)
			elseif string.match(entry["service"], "stream_wma") then
				log:info("asx: ", entry["href"])
				local req = RequestHttp(_sink2ASX(self, playback, data, decode), 'GET', entry["href"], {})
				local uri = req:getURI()
				local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
				http:fetch(req)
			else
				log:info("did not find a playable stream")
			end
			return
		else
			p:parse(content)
		end
	end
end


-- return itterator of preferred service names
function preferredServices(self)
	local order = {
		'iplayer_uk_stream_aac_rtmp_live',      -- start here if not usewma
		'iplayer_uk_stream_aac_rtmp_concrete',
		'iplayer_intl_stream_aac_rtmp_live',
		'iplayer_intl_stream_aac_rtmp_concrete',
		'iplayer_intl_stream_aac_rtmp_ws_live',
		'iplayer_intl_stream_aac_ws_concrete',
		'iplayer_uk_stream_mp3',
		'iplayer_intl_stream_mp3',
		'iplayer_intl_stream_mp3_lo',
		'iplayer_uk_stream_wma',                 -- start here if usewma
		'iplayer_intl_stream_wma',
		'iplayer_intl_stream_wma_live',
		'iplayer_intl_stream_wma_ws',
		'iplayer_intl_stream_wma_uk_concrete',
		'iplayer_intl_stream_wma_lo_concrete'
	}
	local i = self:getSettings()["usewma"] and 9 or 0
	return function()
			   i = i + 1
			   return order[i]
		   end
end


-- sink to parse asx - currently extracts first stream
function _sink2ASX(self, playback, data, decode)
	local streams = {}
	local capture
	local p = lxp.new({
		StartElement = function (parser, name, attr)
			if name == "ref" and attr.href then
				streams[#streams+1] = attr.href
			end
		end,
	})

	return function(content)
		if content == nil then
			p:parse()
			p:close()
			if streams[1] then
				self:_playstreamWMA(playback, data, decode, streams[1])
			else
				log:info("no media url found")
			end
			return
		else
			p:parse(content)
		end
	end
end


-- WMA GUID creation
function makeGUID()
	local guid = ""
	for d = 0, 31 do
		if d == 8 or d == 12 or d == 16 or d == 20 then
			guid = guid .. "-"
		end
		guid = guid .. string.format("%x", math.random(0, 15))
	end
	return guid
end

local GUID = makeGUID()


-- play a WMA stream
function _playstreamWMA(self, playback, data, decode, stream)
	log:info("playing: ", stream)

	-- following is taken from SBS...
	local context, streamtime = 2, 0
	if data.start then
		context = 4
		streamtime = data.start * 1000
	end

	local url = socketurl.parse(stream)
	playback.header =
		"GET " .. url.path .. (url.query and ("?" .. url.query) or "") .. " HTTP/1.0\r\n" ..
		"Accept: */*\r\n" ..
		"User-Agent: NSPlayer/8.0.0.3802\r\n" ..
		"Host: " .. url.host .. "\r\n" ..
		"Pragma: xClientGUID={" .. GUID .. "}\r\n" ..
		"Pragma: no-cache,rate=1.0000000,stream-offset=0:0,max-duration=0\r\n" ..
		"Pragma: stream-time=" .. streamtime .. "\r\n" ..
		"Pragma: request-context=" .. context .. "\r\n" ..
		"Pragma: LinkBW=2147483647, AccelBW=1048576, AccelDuration=21000\r\n" ..
		"Pragma: Speed=5.000\r\n" ..
		"Pragma: xPlayStrm=1\r\n" ..
		"Pragma: stream-switch-count=1\r\n" ..
		"Pragma: stream-switch-entry=ffff:1:0\r\n" ..
		"\r\n"

	self:_playstream(playback, data, decode, url.host, url.port or 80, 'w', 10, string.byte(1), 1)
end


-- play a flash RTMP stream
function _playstreamRTMP(self, playback, data, decode, entry)

	local streamname, tcurl, app, subscribe, codec

	if string.match(entry["service"], "stream_mp3") then

		local play = string.gsub(entry["identifier"], "mp3:", "", 1)
		streamname = entry["identifier"] .. "?auth=" .. entry["authString"] .. "&aifp=v001"
		tcurl      = "rtmp://" .. entry["server"] .. ":80/ondemand?_fcs_vhost=" .. entry["server"] .. "&auth=" .. entry["authString"] ..
			"&aifp=v001&slist=" .. play
		app        = "ondemand?_fcs_vhost=" .. entry["server"] .. "&auth=" .. entry["authString"] .. "&aifp=v001&slist=" .. play
		codec      = "m"

	elseif string.match(entry["service"], "live") then

		streamname = entry["identifier"] .. "?auth=" .. entry["authString"] .. "&aifp=v001"
		subscribe  = entry["identifier"] .. "?auth=" .. entry["authString"] .. "&aifp=v001"
		tcurl      = "rtmp://" .. entry["server"] .. ":80/live?_fcs_vhost=" .. entry["server"] .. "&auth=" .. entry["authString"] ..
			"&aifp=v001&slist=" .. entry["identifier"]
		app        = "live?_fcs_vhost=" .. entry["server"] .. "&auth=" .. entry["authString"] .. "&aifp=v001&slist=" .. entry["identifier"]
		codec      = "a"

	elseif string.match(entry["service"], "stream_aac_rtmp_concrete") then

		-- decode entities on authString?
		streamname = entry["identifier"] .. "?" .. entry["authString"]
		tcurl      = "rtmp://" .. entry["server"] .. ":1935/" .. entry["application"]
		app        = entry["application"]
		codec      = "a"

	elseif string.match(entry["service"], "stream_aac_ws_concrete") then
		
		-- decode entities on authString?
		local play = string.gsub(entry["identifier"], "mp4:", "", 1)
		streamname = entry["identifier"] .. "?" .. entry["authString"]
		tcurl      = "rtmp://" .. entry["server"] .. ":1935/ondemand?_fcs_vhost=" .. entry["server"] .. "&auth=" .. entry["authString"] ..
			"&aifp=v001&slist=" .. play
		app        = "ondemand?_fcs_vhost=" .. entry["server"] .. "&auth=" .. entry["authString"] .. "&aifp=v001&slist=" .. play
		codec      = "a"

	end

	playback.header = "streamname=" .. mime.b64(streamname) .. "&tcurl=" .. mime.b64(tcurl) .. "&app=" .. mime.b64(app) .. 
		"&meta=" .. mime.b64("none") .. "&"

	if subscribe then
		playback.header = playback.header .. "&subname=" .. mime.b64(subscribe) .. "&live=" .. mime.b64(1) .. "&"
	end
	if data.start then
		playback.header = playback.header .. "&start=" .. mime.b64(data.start) .. "&"
	end

	playback.flags = 0x20 -- force use of Rtmp handler
	self:_playstream(playback, data, decode, entry["server"], 1935,
					 codec,                                    -- codec id
					 codec == "a" and 0 or 1,                  -- outputthresh
					 codec == "a" and string.byte('2') or nil, -- samplesize
					 nil)                                      -- samplerate
end


-- find the ip address, setup the decoder and start playback - done in a task to allow dns to work
function _playstream(self, playback, data, decode, host, port, codec, outputthresh, samplesize, samplerate)

	Task("playstream", self, function()
								 local ip = dns:toip(host)
								 if ip then
									 log:info("playing stream codec ", codec, " host: ", host, " ip: ", ip, " port: ", port)
									 decode:start(string.byte(codec),
												  string.byte(data.transitionType),
												  data.transitionPeriod,
												  data.replayGain,
												  outputthresh or data.outputThreshold,
												  data.flags & 0x03,
												  samplesize or string.byte(data.pcmSampleSize),
												  samplerate or string.byte(data.pcmSampleRate),
												  string.byte(data.pcmChannels),
												  string.byte(data.pcmEndianness)
											  )
									 playback:_streamConnect(ip, port)
								 else
									 log:warn("bad dns lookup for ", entry["server"])
								 end
							 end
	):addTask()
end

