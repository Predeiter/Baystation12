GLOBAL_DATUM_INIT(wizards, /datum/antagonist/wizard, new)

/datum/antagonist/wizard
	id = MODE_WIZARD
	role_text = ANTAG_WIZARD
	role_text_plural = ANTAG_WIZARD + "s"
	landmark_id = "wizard"
	welcome_text = "Вы найдете список доступных заклинаний в своей книге заклинаний. Тщательно подготовьте свой магический арсенал.<br>В ваших карманах вы найдете свиток телепортации. Используйте его как только понадобится."
	flags = ANTAG_OVERRIDE_JOB | ANTAG_OVERRIDE_MOB | ANTAG_CLEAR_EQUIPMENT | ANTAG_CHOOSE_NAME | ANTAG_VOTABLE | ANTAG_SET_APPEARANCE
	antaghud_indicator = "hudwizard"

	hard_cap = 1
	hard_cap_round = 3
	initial_spawn_req = 1
	initial_spawn_target = 1
	min_player_age = 18

	faction = "wizard"
	base_to_load = /datum/map_template/ruin/antag_spawn/wizard

/datum/antagonist/wizard/create_objectives(var/datum/mind/wizard)

	if(!..())
		return

	var/kill
	var/escape
	var/steal
//	var/hijack

	switch(rand(1,99))
		if(1 to 30)
			escape = 1
			kill = 1
		if(31 to 60)
			escape = 1
			steal = 1
		else
			kill = 1
			steal = 1
//		else
//			hijack = 1

	if(kill)
		var/datum/objective/assassinate/kill_objective = new
		kill_objective.owner = wizard
		kill_objective.find_target()
		wizard.objectives |= kill_objective
	if(steal)
		var/datum/objective/steal/steal_objective = new
		steal_objective.owner = wizard
		steal_objective.find_target()
		wizard.objectives |= steal_objective
	if(escape)
		var/datum/objective/survive/survive_objective = new
		survive_objective.owner = wizard
		wizard.objectives |= survive_objective
//	if(hijack)
//		var/datum/objective/hijack/hijack_objective = new
//		hijack_objective.owner = wizard
//		wizard.objectives |= hijack_objective
	return

/datum/antagonist/wizard/update_antag_mob(var/datum/mind/wizard)
	..()
	wizard.StoreMemory("<B>Помните:</B> не забудьте подготовить свои заклинания.", /decl/memory_options/system)
	wizard.current.real_name = "[pick(GLOB.wizard_first)] [pick(GLOB.wizard_second)]"
	wizard.current.SetName(wizard.current.real_name)

/datum/antagonist/wizard/equip(var/mob/living/carbon/human/wizard_mob)

	if(!..())
		return 0

	var/outfit_type = pick(subtypesof(/decl/hierarchy/outfit/wizard))
	var/decl/hierarchy/outfit/wizard_outfit = outfit_by_type(outfit_type)
	wizard_outfit.equip(wizard_mob)

	return 1

/datum/antagonist/wizard/print_player_summary()
	..()
	for(var/p in current_antagonists)
		var/datum/mind/player = p
		var/text = "<b>[player.name]'s spells were:</b>"
		if(!player.learned_spells || !player.learned_spells.len)
			text += "<br>None!"
		else
			for(var/s in player.learned_spells)
				var/spell/spell = s
				text += "<br><b>[spell.name]</b> - "
				text += "Speed: [spell.spell_levels["speed"]] Power: [spell.spell_levels["power"]]"
		text += "<br>"
		to_world(text)


//To batch-remove wizard spells. Linked to mind.dm.
/mob/proc/spellremove()
	if(!mind || !mind.learned_spells)
		return
	for(var/spell/spell_to_remove in mind.learned_spells)
		remove_spell(spell_to_remove)

obj/item/clothing
	var/wizard_garb = FALSE

// Does this clothing slot count as wizard garb? (Combines a few checks)
/proc/is_wiz_garb(var/obj/item/clothing/C)
	return istype(C) && C.wizard_garb

/*Checks if the wizard is wearing the proper attire.
Made a proc so this is not repeated 14 (or more) times.*/
/mob/proc/wearing_wiz_garb()
	to_chat(src, "Глупое создание, ты не человек. Только люди могут создать это заклинание.")
	return 0

// Humans can wear clothes.
/mob/living/carbon/human/wearing_wiz_garb()
	if(!is_wiz_garb(wear_suit) && (!species.hud || (slot_wear_suit in species.hud.equip_slots)))
		to_chat(src, "<span class='warning'>Я не чувствую себя достаточно сильным без своей мантии.</span>")
		return 0
	if(!is_wiz_garb(shoes) && (!species.hud || (slot_shoes in species.hud.equip_slots)))
		to_chat(src, "<span class='warning'>Я не чувствую себя достаточно сильным без своей обуви.</span>")
		return 0
	if(!is_wiz_garb(head) && (!species.hud || (slot_head in species.hud.equip_slots)))
		to_chat(src, "<span class='warning'>Я не чувствую себя достаточно сильным без своей шляпы.</span>")
		return 0
	return 1
