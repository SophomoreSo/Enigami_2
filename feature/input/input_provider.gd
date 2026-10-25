class_name InputProvider
extends RefCounted

## What a body is asked to do, from one place — and the line it comes down,
## which anything in the game may stand on to have a say in it.
##
## After aarthificial's "Stealing Control from Players" (Legacy Devlog #22),
## worked from its transcript. Several systems want the player's body at once:
## their own hands, a screen over the game that takes the keys, a conversation
## that holds them still, a walk that brings them over to talk. None of them
## should have to know about the others, and the body should know none of
## them. So the body asks one thing, `state()`, and that builds the frame's
## `InputState` by passing an empty one down a line of `InputMiddleware`s,
## each adding its say. Whatever comes out the far end is what the body does.
##
## The player keeps one, `Player.input`, with their `Hands` at the head of it. A
## system that wants the player's body puts something on that line and takes it
## off again, or lets it finish: a finished middleware leaves by itself. The
## line hangs on the player rather than on the game, so a world swapped out takes
## its player's line with it, and nothing it put there can outlive them.

## The body the line drives, handed to every middleware that joins it.
var body: Node2D = null
var _line: Array[InputMiddleware] = []

func _init(driving: Node2D = null) -> void:
	body = driving

## This frame, as the whole line leaves it. The body asks once in each physics
## frame and once in each drawn one. Nothing on the line goes faster for being
## asked more often, but a middleware that finishes leaves with the reading it
## finished in — so anything else that wants to know what the body was asked
## should ask the body, not its line.
func state() -> InputState:
	var s := InputState.new()
	# A copy, so a middleware may join the line or leave it from inside its own
	# turn without moving the one after it.
	for m: InputMiddleware in _line.duplicate():
		if not m.done:
			s = m.process(s)
	s.apply_gates()
	for i in range(_line.size() - 1, -1, -1):
		if _line[i].done:
			_line.remove_at(i)
	return s

## Has the line drive `driving` from now on: everything on it — the hands'
## aim, a walk over to someone, aim assist — measures from that body instead.
## The player's line drives a monster for as long as they are inside one
## (`Player.possess`), and their own body again once they step out.
func drive(driving: Node2D) -> void:
	body = driving
	for m in _line:
		m.body = driving

## Puts `m` on the line, at the back of its rank. It stays until it is taken off
## or it is done.
func add(m: InputMiddleware) -> void:
	if _line.has(m):
		return
	m.body = body
	var at := _line.size()
	for i in _line.size():
		if _line[i].rank > m.rank:
			at = i
			break
	_line.insert(at, m)

func remove(m: InputMiddleware) -> void:
	_line.erase(m)

func has(m: InputMiddleware) -> bool:
	return _line.has(m)

## Whether anything on the line has taken the hands off the body, whoever put
## it there.
func held() -> bool:
	for m in _line:
		if m is HandsOff and not m.done:
			return true
	return false

## Whether the computer has the body rather than the player: something on the
## line has taken it over — a hold that is the game's own, a walk, another pair
## of hands (`InputMiddleware.takes_over`).
func taken_over() -> bool:
	for m in _line:
		if not m.done and m.takes_over():
			return true
	return false

## On the line or off it, as `on` says: for something that comes and goes with
## a flag.
func put(m: InputMiddleware, on: bool) -> void:
	if on:
		add(m)
	else:
		remove(m)
