## Builds detached AI snapshots and production-backed configuration without a scene or renderer.
extends RefCounted

const FormalFixture = preload("res://tests/support/formal_match_fixture.gd")
var formal := FormalFixture.new()
var tuning: AIBehaviorConfig
var rules: MatchConfigDefinition

## Uses the same table loaders as formal production assembly.
func _init() -> void:
	tuning = formal.data.load_ai_config()
	rules = formal.config()

## Copies a supplied test arrangement; state mutations are confined to explicit fixture setup.
func snapshot(players: Array[PlayerRuntime], ball: BallMatchState, kicker: String = "",
		sequence: int = 1, touched: bool = false, step: int = 0) -> MatchStateSnapshot:
	var copies: Array[PlayerStateSnapshot] = []
	for player in players:
		copies.append(PlayerStateSnapshot.new(player.state, player.team_id, player.is_goalkeeper, player))
	return MatchStateSnapshot.new(MatchState.Phase.RUNNING, float(step) / 60.0, step, 42, copies,
		BallStateSnapshot.new(ball, null, 0.0, 0, kicker, sequence, touched))

func player(id: String, point: Vector2 = Vector2.ZERO, team: String = "home",
		keeper: bool = false) -> PlayerRuntime:
	return PlayerRuntime.new(id, point, 5.0, team, 84, 80, 80, keeper)

## Collects source proposals through the production loop, not by directly writing player positions.
func source(with_regions: bool = false) -> MatchPlayerAISource:
	return MatchPlayerAISource.new(formal.teams, formal.field, rules, tuning, null, null,
		1.0 / 60.0, formal.data.load_activity_regions() if with_regions else null)
