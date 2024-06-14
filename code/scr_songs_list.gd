class_name SongsList extends RefCounted

# list of all music

var songs := {
	"air_conditioning": {
		"title": "air conditioning",
		"stream": preload("res://music/mus_air_conditioning.ogg")
	},
	"ac_scary": {
		"title": "ac_scary",
		"stream": preload("res://music/mus_ac_scary.ogg")
	},
	"arent_you_excited": {
		"title": "aren't you excited?",
		"stream": preload("res://music/mus_arent_you_excited.ogg")
	},
	"best": {
		"title": "soundtrack highlight",
		"stream": preload("res://music/mus_best.ogg")
	},
	"bike_beta": {
		"title": "personal transport apparition",
		"stream": preload("res://music/mus_bike_beta.ogg")
	},
	"bike_spirit": {
		"title": "bike spirit",
		"stream": preload("res://music/mus_bike_spirit.ogg")
	},
	"bike_spirit_appear": {
		"title": "a bike spirit appears!",
		"stream": preload("res://music/mus_bike_spirit_appear.ogg")
	},
	"birds": {
		"title": "birdsong",
		"stream": preload("res://music/mus_birds.ogg")
	},
	"catfight": {
		"title": "catfight",
		"stream": preload("res://music/mus_catfight.ogg")
	},
	"daylightthief": {
		"title": "daylightthief",
		"stream": preload("res://music/mus_daylightthief.ogg")
	},
	"defeat": {
		"title": "so guys, we died it",
		"stream": preload("res://music/mus_defeat.ogg"),
		"loop": false
	},
	"development_hell": {
		"title": "development hell",
		"stream": preload("res://music/mus_development_hell.ogg")
	},
	"dishout": {
		"title": "dishout",
		"stream": preload("res://music/mus_dishout.ogg"),
		"default_volume": 2
	},
	"dry_summer": {
		"title": "dry summer",
		"stream": preload("res://music/mus_dry_summer.ogg")
	},
	"entirely_just": {
		"title": "entirely just",
		"stream": preload("res://music/mus_entirely_just.ogg")
	},
	"extremophile": {
		"title": "extremophile",
		"stream": preload("res://music/mus_extremophile.ogg"),
	},
	"favourable_silence": {
		"title": "favourable silence",
		"stream": preload("res://music/mus_favourable_silence.ogg"),
		"default_volume": -5,
	},
	"fisher_hut": {
		"title": "radio & murumart - a smoke in the tropical paradise that is a fisherman's hut",
		"stream": preload("res://music/mus_fisher_hut.ogg"),
	},
	"fishing_game": {
		"title": "i will dip you in saurce",
		"stream": preload("res://music/mus_fishing_game.ogg"),
	},
	"foreign_fauna": {
		"title": "foreign fauna",
		"stream": preload("res://music/mus_animal_fight.ogg"),
	},
	"gaming": {
		"title": "gaming",
		"stream": preload("res://music/mus_gaming.ogg")
	},
	"geezer": {
		"title": "quit PISSING ME OFF GEEZER",
		"stream": preload("res://music/mus_geezer.ogg")
	},
	"greenhouse": {
		"title": "webcatz - greenhouse",
		"stream": preload("res://music/mus_greenhouse.ogg")
	},
	"grandma_scary": {
		"title": "mental",
		"stream": preload("res://music/mus_grandma_scary.ogg")
	},
	"greg_battle": {
		"title": "greg battle",
		"stream": preload("res://music/mus_greg_battle.ogg")
	},
	"lakeside": {
		"title": "whale of a time",
		"stream": preload("res://music/mus_lakeside.ogg")
	},
	"lake_battle": {
		"title": "drum and perch",
		"stream": preload("res://music/mus_lake_battle.ogg")
	},
	"lily_lesson": {
		"title": "lily lesson",
		"stream": preload("res://music/mus_lily_lesson.ogg")
	},
	"lion": {
		"title": "lion",
		"stream": preload("res://music/mus_lion.ogg")
	},
	"mail_mission": {
		"title": "mail mission",
		"stream": preload("res://music/mus_mail_mission.ogg")
	},
	"police": {
		"title": "poosetajad",
		"stream": preload("res://music/mus_police.ogg")
	},
	"preturberance": {
		"title": "perturberance",
		"stream": preload("res://music/mus_perturberance.ogg")
	},
	"overrun": {
		"title": "overrun",
		"stream": preload("res://music/mus_overrun.ogg")
	},
	"shitty_entrance_of_the_gladiators": {
		"title": "julius fucik - entrance of the gladiators",
		"stream": preload("res://music/mus_entrance_of_the_gladiators.ogg")
	},
	"snail_mourning": {
		"title": "snail mourning",
		"stream": preload("res://music/mus_snail_mourning.ogg")
	},
	"staredown": {
		"title": "staredown",
		"stream": preload("res://music/mus_staredown.ogg")
	},
	"mail_man": {
		"title": "the friendly postman",
		"stream": preload("res://music/mus_mail_man.ogg")
	},
	"president_fight": {
		"title": "touch me",
		"stream": preload("res://music/mus_president_fight.ogg")
	},
	"touch_me": {
		"title": "touch me",
		"stream": preload("res://music/mus_touch_me.ogg")
	},
	"vampire_fight": {
		"title": "girl unboxing",
		"stream": preload("res://music/mus_vampire_fight.ogg"),
	},
	"victory": {
		"title": "so guys, we did it",
		"stream": preload("res://music/mus_victory.ogg"),
		"loop": false
	},
	"warstory": {
		"title": "stood down and greeted us",
		"stream": preload("res://music/mus_warstory.ogg"),
		"loop": false
	}
}


func _init() -> void:
	for i in 7:
		songs["menu_%s" % (i + 1)] = {
			"title": ("radio - menu%s" % (i + 1)),
			"stream": load("res://music/menu/mus_menu%s.ogg" % (i + 1)),
			"loop": false
		}
