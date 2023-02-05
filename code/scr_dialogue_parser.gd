extends RefCounted
class_name DialogueParser

enum {COMMENT, SET_DIAL, SET_CHAR, SET_LINE, SET_TEXT_SPEED, SET_CHOICES, SET_CHOICE_LINK}

const NEW_DIAL := "DIALOGUE "
const NEW_CHAR := "CHAR "
const NEW_TXT_SPD := "SPEED "
const NEW_LINE := "\t"
const NEW_CHOICES := "CHOICES "
const NEW_CHOICE_LINK := "CHOICE_LINK "


func parse_dialogue_from_file(file_as_text: String) -> Array[Dialogue]:
	print("parsing dialogue...")
	var time := Time.get_ticks_usec()
	var lines := file_as_text.split("\n")
	var mode := COMMENT
	var dialogue_array : Array[Dialogue] = []
	var dial : Dialogue
	var dial_line : DialogueLine
	var char_to_set := ""
	var text_speed_to_set := 1.0
	var choices_to_set : PackedStringArray = []
	var choice_link_to_set : StringName = &""
	var l := -1
	
	for line in lines:
		l += 1
		if line.begins_with(NEW_DIAL):
			mode = SET_DIAL
			if not dial == null:
				dialogue_array.append(dial.duplicate())
				dial = null
			char_to_set = ""
			text_speed_to_set = 1.0
			choices_to_set = []
			choice_link_to_set = &""
			dial = Dialogue.new()
			dial.name = line.trim_prefix(NEW_DIAL)
		elif line.begins_with(NEW_CHAR):
			mode = SET_CHAR
			char_to_set = String(line.trim_prefix(NEW_CHAR))
		elif line.begins_with(NEW_TXT_SPD):
			mode = SET_TEXT_SPEED
			text_speed_to_set = float(line.trim_prefix(NEW_TXT_SPD))
		elif line.begins_with(NEW_CHOICES):
			mode = SET_CHOICES
			choices_to_set = line.trim_prefix(NEW_CHOICES).split(",")
		elif line.begins_with(NEW_CHOICE_LINK):
			mode = SET_CHOICE_LINK
			choice_link_to_set = line.trim_prefix(NEW_CHOICE_LINK)
		elif line.begins_with(NEW_LINE):
			mode = SET_LINE
			dial_line = DialogueLine.new()
			dial_line.text = line.trim_prefix(NEW_LINE)
			dial_line.character = char_to_set
			dial_line.text_speed = text_speed_to_set
			dial_line.choice_link = choice_link_to_set
			if choices_to_set:
				dial_line.choices = choices_to_set
				choices_to_set = []
			dial.lines.append(dial_line.duplicate())
			dial_line = null
		else:
			mode = COMMENT
		if l + 1 >= lines.size():
			dialogue_array.append(dial)
	
	if mode: pass
	print("parsing finished. ", Time.get_ticks_usec() - time)
	return dialogue_array

