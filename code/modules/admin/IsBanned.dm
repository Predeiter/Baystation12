
//These are exclusive, so once it goes over one of these numbers, it reverts the ban
#define STICKYBAN_MAX_MATCHES 20
#define STICKYBAN_MAX_EXISTING_USER_MATCHES 5 //ie, users who were connected before the ban triggered
// Смешанный IsBanned с проверкой массовых стик-банов (/tg/) и защитой от DOS (Nebula) ~bear1ake
//Blocks an attempt to connect before even creating our client datum thing.
/world/IsBanned(key, address, computer_id, type)
	var/static/key_cache = list()
	if(type == "world")
		return ..()

	if(key_cache[key] >= REALTIMEOFDAY)
		return list("reason"="concurrent connection attempts", "desc"="You are attempting to connect too fast. Try again.")
	key_cache[key] = REALTIMEOFDAY + 10 //This proc shouldn't be runtiming. But if it does, then the expiry time will cover it to ensure genuine connection attempts don't get trapped in limbo.

	if(ckey(key) in admin_datums)
		key_cache[key] = 0
		return ..()

	if (text2num(computer_id) == 2147483647) //this cid causes stickybans to go haywire
		log_access("Failed Login (invalid cid): [key] [address]-[computer_id]")
		key_cache[key] = 0
		return list("reason"="invalid login data", "desc"="Error: Could not check ban status, Please try again. Error message: Your computer provided an invalid Computer ID.)")

	//Guest Checking
	if(!config.guests_allowed && IsGuestKey(key))
		log_access("Failed Login: [key] - Guests not allowed")
		message_admins("<span class='notice'>Failed Login: [key] - Guests not allowed</span>")
		key_cache[key] = 0
		return list("reason"="guest", "desc"="\nReason: Guests not allowed. Please sign in with a byond account.")

	var/ckeytext = ckey(key)
	var/client/C = GLOB.ckey_directory[ckeytext]
	//If this isn't here, then topic call spam will result in all clients getting kicked with a connecting too fast error.
	if (C && ckeytext == C.ckey && address == C.address && computer_id == C.computer_id)
		key_cache[key] = 0
		return

	if(config.ban_legacy_system)

		//Ban Checking
		. = CheckBan( ckey(key), computer_id, address )
		if(.)
			log_access("Failed Login: [key] [computer_id] [address] - Banned [.["reason"]]")
			message_admins("<span class='notice'>Failed Login: [key] id:[computer_id] ip:[address] - Banned [.["reason"]]</span>")
			key_cache[key] = 0
			return .

		key_cache[key] = 0
		return ..()	//default pager ban stuff

	else

		if(!establish_db_connection())
			error("Ban database connection failure. Key [ckeytext] not checked")
			log_misc("Ban database connection failure. Key [ckeytext] not checked")
			key_cache[key] = 0
			return

		var/failedcid = 1
		var/failedip = 1

		if (config.minimum_player_age && get_player_age(key) < config.minimum_player_age)
			message_admins("[key] tried to join but did not meet the configured minimum player age.")
			return list("reason"="player age", "desc"="This server is not currently allowing accounts with a low number of days since first connection to join.")

		var/ipquery = ""
		var/cidquery = ""
		if(address)
			failedip = 0
			ipquery = " OR ip = '[address]' "

		if(computer_id)
			failedcid = 0
			cidquery = " OR computerid = '[computer_id]' "

		var/DBQuery/query = dbcon.NewQuery("SELECT ckey, a_ckey, reason, expiration_time, duration, bantime, bantype FROM [sqlfdbkdbutil].ban WHERE (ckey = '[ckeytext]' [ipquery] [cidquery]) AND (bantype = 'PERMABAN'  OR (bantype = 'TEMPBAN' AND expiration_time > Now())) AND isnull(unbanned)")

		query.Execute()

		while(query.NextRow())
			var/pckey = query.item[1]
			var/ackey = query.item[2]
			var/reason = query.item[3]
			var/expiration = query.item[4]
			var/duration = query.item[5]
			var/bantime = query.item[6]
			var/bantype = query.item[7]

			var/expires = ""
			if(text2num(duration) > 0)
				expires = " The ban is for [minutes_to_readable(duration)] and expires on [expiration] (server time)."

			var/desc = "\nReason: You, or another user of this computer or connection ([pckey]) is banned from playing here. The ban reason is:\n[reason]\nThis ban was applied by [ackey] on [bantime], [expires]"

			key_cache[key] = 0
			. = list("reason"="[bantype]", "desc"="[desc]")

		if (failedcid)
			message_admins("[key] has logged in with a blank computer id in the ban check.")
		if (failedip)
			message_admins("[key] has logged in with a blank ip in the ban check.")

	key_cache[key] = 0
	var/list/ban = ..()	//default pager ban stuff
	var/ckey = ckey(key)
	if (ban)
		var/bannedckey = "ERROR"
		if (ban["ckey"])
			bannedckey = ban["ckey"]

		var/newmatch = FALSE
		var/cachedban = SSstickyban.cache[bannedckey]

		//rogue ban in the process of being reverted.
		if (cachedban && cachedban["reverting"])
			return null

		if (cachedban && ckey != bannedckey)
			newmatch = TRUE
			if (cachedban["keys"])
				if (cachedban["keys"][ckey])
					newmatch = FALSE
			if (cachedban["matches_this_round"][ckey])
				newmatch = FALSE

		if (newmatch && cachedban)
			var/list/newmatches = cachedban["matches_this_round"]
			var/list/newmatches_connected = cachedban["existing_user_matches_this_round"]

			newmatches[ckey] = ckey
			if (C)
				newmatches_connected[ckey] = ckey

			if (\
				newmatches.len > STICKYBAN_MAX_MATCHES || \
				newmatches_connected.len > STICKYBAN_MAX_EXISTING_USER_MATCHES \
				)
				if (cachedban["reverting"])
					return null
				cachedban["reverting"] = TRUE

				world.SetConfig("ban", bannedckey, null)

				log_game("Stickyban on [bannedckey] detected as rogue, reverting to its roundstart state")
				message_admins("Stickyban on [bannedckey] detected as rogue, reverting to its roundstart state")
				//do not convert to timer.
				spawn (5)
					world.SetConfig("ban", bannedckey, null)
					sleep(1)
					world.SetConfig("ban", bannedckey, null)
					cachedban["matches_this_round"] = list()
					cachedban["existing_user_matches_this_round"] = list()
					cachedban["admin_matches_this_round"] = list()
					cachedban -= "reverting"
					world.SetConfig("ban", bannedckey, list2stickyban(cachedban))
				return null

		if (C) //user is already connected!.
			to_chat(C, "You are about to get disconnected for matching a sticky ban after you connected. If this turns out to be the ban evasion detection system going haywire, we will automatically detect this and revert the matches. if you feel that this is the case, please wait EXACTLY 6 seconds then reconnect using file -> reconnect to see if the match was reversed.")

		var/desc = "\nПричина:(Стикбан) Вы или другой пользователь этого устройства (или IP) с ником ([bannedckey]) были ограничены в доступе на сервер на неопределенный срок по причине:\n[ban["message"]]\n.  Выдавший блокировку: [ban["admin"]]\n. Если данная блокировка ошибочка, то обратитесь в раздел с судом на нашем дискорд-сервере.\n"
		. = list("reason" = "Stickyban", "desc" = desc)
		log_access("Failed Login: [key] [computer_id] [address] - StickyBanned [ban["message"]] Target Username: [bannedckey] Placed by [ban["admin"]]")

	return .
