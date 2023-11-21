class_name Genders extends RefCounted

enum {
	ELECTRIC,
	SOPPING,
	FLAMING,
	GHOST,
	BRAIN,
	VAST
}

const CIRCLE := {
	ELECTRIC: SOPPING,
	SOPPING: FLAMING,
	FLAMING: GHOST,
	GHOST: BRAIN,
	BRAIN: VAST,
	VAST: ELECTRIC
}
