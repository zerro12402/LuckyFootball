## Resolves F08 and ball response from explicit contact and an independent F07 outcome.
class_name BallImpactResolver
extends RefCounted

## Draws exactly once after a high-speed strict-greater knockdown; dodge/hit need no route dice.
static func resolve(contact: BallContactCandidate, source: BallShotSource, strength: int,
		velocity: Vector2, config: MatchConfigDefinition, sample_route: Callable,
		did_dodge: bool = false) -> BallImpactResult:
	assert(contact != null and source != null and config != null)
	if did_dodge:
		return BallImpactResult.new(contact, source, strength, velocity, velocity,
			true, false, BallImpactResult.Route.CONTINUE)
	var knocked_down := (velocity.length() >= config.ball_impact_min_speed_mps
		and source.shooting >= strength)
	var sample := -1.0
	var route := BallImpactResult.Route.REBOUND
	if knocked_down and source.shooting > strength:
		sample = float(sample_route.call())
		assert(sample >= 0.0 and sample < 1.0, "Route sample must be in [0, 1)")
		if sample < 0.5:
			route = BallImpactResult.Route.CONTINUE
	var after := velocity
	if route == BallImpactResult.Route.REBOUND:
		var normal_velocity := contact.normal * velocity.dot(contact.normal)
		after = (velocity - normal_velocity) * config.ball_impact_tangent_retention
		after -= normal_velocity * config.ball_impact_normal_retention
	return BallImpactResult.new(contact, source, strength, velocity, after,
		false, knocked_down, route, sample)
