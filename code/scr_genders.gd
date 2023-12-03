class_name Genders extends RefCounted

enum {
	NONE,
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

enum Kin {
  pi = 314159,
  mantissa = 1,
  red = 16719904,
  XML = 0
}


static func apply_gender_effects(amount: float, gender_own: int, gender_consider) -> float:
	if gender_consider == CIRCLE.get(gender_own, -1):
		amount *= 1.5
	if gender_own == SOPPING and gender_consider == FLAMING:
		amount *= 0.5
	return amount