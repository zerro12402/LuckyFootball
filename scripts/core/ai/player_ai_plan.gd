## Stores only AI intent and review timing; PlayerStateMachine remains the sole action-state owner.
class_name PlayerAIPlan
extends RefCounted

var action: MatchAction
var target_m: Vector2
var started_at: float
var next_review_at: float
var expires_at: float
var owner_id: String
var tactical_phase: int
var was_sent: bool = false
var flight_sequence: int
var behavior: int = AIActionCandidate.Behavior.HOLD
var primary_player_id: String = ""
var had_contest_opportunity: bool = false

## Anchors review and timeout deadlines to simulation time, not display frames or wall-clock time.
func _init(intent: MatchAction, destination: Vector2, snapshot: MatchStateSnapshot,
		phase: int, config: AIBehaviorConfig) -> void:
	action = intent
	target_m = destination
	started_at = snapshot.elapsed_seconds
	next_review_at = started_at + config.number("heartbeat_seconds")
	expires_at = started_at + config.number("plan_timeout_seconds")
	owner_id = snapshot.ball.owner_player_id
	tactical_phase = phase
	flight_sequence = snapshot.ball.flight_sequence
