## Describes a geometric contact before contests or match-state changes are committed.
class_name BallContactCandidate
extends RefCounted

enum Kind { BOUNDARY, GOALKEEPER, PLAYER }

var kind: Kind = Kind.PLAYER
var player_id: String = ""
var time_seconds: float = 0.0
var position_m: Vector2 = Vector2.ZERO
var player_position_m: Vector2 = Vector2.ZERO
var height_m: float = 0.0
var normal: Vector2 = Vector2.LEFT
var boundary: MatchBoundaryResult
