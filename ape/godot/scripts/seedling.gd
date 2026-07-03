@tool
extends Node2D

## Plant lifecycle: GROWING -> BLOOMED -> POLLINATED -> SEED_GROWING -> (seed
## pops) -> BLOOMED. Watering drives GROWING; POLLINATED is entered by
## pollinate(), SEED_GROWING by watering a POLLINATED plant again.
enum State { GROWING, BLOOMED, POLLINATED, SEED_GROWING }

## Emitted when a SEED_GROWING plant finishes swelling its pod and pops a
## seed. Main listens for this on every Seedling to spawn seed.tscn — the
## plant itself doesn't know about scenes/spawning, per CODING.md's
## signals-over-tree-reaching rule.
signal seed_popped(hybrid_type: PlantData.PlantType, at_position: Vector2)

const MIN_SCALE: float = 0.12
const BLOOM_START: float = 70.0

## Result of a pollinate() call: whether the incoming pollen produced a
## hybrid or fizzled. Same-type pollination is filtered out by the caller
## (the plant's own bloom_type) before pollinate() is ever invoked.
enum PollinateResult { SUCCESS, FIZZLE }

var state: State = State.GROWING:
	set(value):
		state = value
		# The POLLINATED shimmer is only animated during actual gameplay —
		# gating set_process on the editor hint keeps the @tool preview
		# static (like growth/bloom_type already are) instead of animating
		# inside the editor.
		set_process(state == State.POLLINATED and not Engine.is_editor_hint())
		_update_visuals()

## Hybrid type resolved by a successful pollinate() call, held until it pops
## as a seed.
var hybrid_result: PlantData.PlantType = PlantData.PlantType.NONE

## Progress through SEED_GROWING (0-100), mirroring how `growth` tracks
## GROWING. Kept as a plain var rather than exported: no seedling instance
## ever starts POLLINATED/SEED_GROWING, so there's nothing to author.
var seed_progress: float = 0.0:
	set(value):
		seed_progress = clampf(value, 0.0, 100.0)
		if state == State.POLLINATED and seed_progress > 0.0:
			state = State.SEED_GROWING
		elif state == State.SEED_GROWING and seed_progress >= 100.0:
			_pop_seed()
		else:
			_update_visuals()

var _shimmer_t: float = 0.0

## Progress through the GROWING state; kept exported so instances in the level
## can start part-grown and the @tool preview stays live in the editor.
@export_range(0.0, 100.0) var growth: float = 100.0:
	set(value):
		growth = clampf(value, 0.0, 100.0)
		if state == State.GROWING and growth >= 100.0:
			state = State.BLOOMED
		elif state == State.BLOOMED and growth < 100.0:
			state = State.GROWING
		else:
			_update_visuals()

## Seconds of continuous watering to grow from 0% to 100%.
@export var grow_time: float = 5.0

## Seconds of continuous watering for a POLLINATED plant to swell and pop a
## seed.
@export var seed_grow_time: float = 4.0

@export var bloom_type: PlantData.PlantType = PlantData.PlantType.DAISY:
	set(value):
		bloom_type = value
		_update_visuals()

@onready var bud: Polygon2D = $Sprout/Bud
@onready var bloom: Node2D = $Bloom
@onready var pollen_cue: Node2D = $Bloom/PollenCue
@onready var sparkle: CPUParticles2D = $Bloom/Sparkle
@onready var seed_pod: Polygon2D = $Bloom/SeedPod
@onready var seed_pop_puff: CPUParticles2D = $SeedPopPuff
@onready var seed_pop_sound: AudioStreamPlayer2D = $SeedPopSound
@onready var _pollen_dots: Array[Polygon2D] = [
	$Bloom/PollenCue/Dot1, $Bloom/PollenCue/Dot2, $Bloom/PollenCue/Dot3,
]
@onready var _blooms: Dictionary = {
	PlantData.PlantType.DAISY: $Bloom/Daisy,
	PlantData.PlantType.TULIP: $Bloom/Tulip,
	PlantData.PlantType.BERRY: $Bloom/Berry,
	PlantData.PlantType.APPLE: $Bloom/Apple,
	PlantData.PlantType.SUNFLOWER: $Bloom/Sunflower,
}


func _ready() -> void:
	# Instances that keep the default growth value never run its setter, so
	# derive the starting state here instead of trusting the default.
	state = State.BLOOMED if growth >= 100.0 else State.GROWING


## Same hover-and-drain mechanic as growing (see player.gd's watering poll) —
## which progress bar a tick of watering advances depends on lifecycle state.
func water(delta: float) -> void:
	match state:
		State.GROWING:
			growth += 100.0 / grow_time * delta
		State.POLLINATED, State.SEED_GROWING:
			seed_progress += 100.0 / seed_grow_time * delta


## Collects this plant's pollen. Only meaningful while BLOOMED — callers
## (player.gd) are expected to check state first. Doesn't change plant
## state; pollen is not consumed or depleted by collection.
func collect_pollen() -> PlantData.PlantType:
	return bloom_type


## Attempts to pollinate this BLOOMED plant with incoming pollen of a
## different type than its own (same-type is the caller's responsibility to
## filter out beforehand). On success, resolves and stores the hybrid result
## and advances to POLLINATED; on fizzle, state is left unchanged.
func pollinate(incoming: PlantData.PlantType) -> PollinateResult:
	var result: PlantData.PlantType = PlantData.combo_result(incoming, bloom_type)
	if result == PlantData.PlantType.NONE:
		return PollinateResult.FIZZLE
	hybrid_result = result
	state = State.POLLINATED
	return PollinateResult.SUCCESS


## Finishes SEED_GROWING: fires the pop feedback, reverts to BLOOMED (seeds
## are renewable, per REQUIREMENTS.md), and hands the popped type off via
## seed_popped for whoever owns spawning seed.tscn into the level.
func _pop_seed() -> void:
	var popped_type: PlantData.PlantType = hybrid_result
	seed_pop_puff.restart()
	seed_pop_puff.emitting = true
	seed_pop_sound.pitch_scale = randf_range(0.9, 1.1)
	seed_pop_sound.play()
	# Leave SEED_GROWING before clearing hybrid_result: _update_visuals()
	# reads PlantData.seed_color(hybrid_result) whenever the pod is visible,
	# and SEED_COLORS has no NONE entry.
	state = State.BLOOMED
	hybrid_result = PlantData.PlantType.NONE
	seed_progress = 0.0
	seed_popped.emit(popped_type, global_position)


func _process(delta: float) -> void:
	_shimmer_t += delta
	bloom.modulate = Color(1.0, 1.0, 1.0) * (1.0 + 0.15 * sin(_shimmer_t * 4.0))


## Every visual is a function of (state, progress, bloom_type) — no visual
## state is stored anywhere else.
func _update_visuals() -> void:
	if not is_node_ready():
		return
	scale = Vector2.ONE * lerpf(MIN_SCALE, 1.0, growth / 100.0)
	var bloom_t: float = clampf((growth - BLOOM_START) / (100.0 - BLOOM_START), 0.0, 1.0)
	bloom.visible = bloom_t > 0.0
	bloom.scale = Vector2.ONE * bloom_t
	bud.visible = bloom_t <= 0.0
	for type: PlantData.PlantType in _blooms:
		_blooms[type].visible = type == bloom_type
	pollen_cue.visible = state == State.BLOOMED
	var pollen_color: Color = PlantData.pollen_color(bloom_type)
	for dot: Polygon2D in _pollen_dots:
		dot.color = pollen_color
	sparkle.emitting = state == State.POLLINATED
	if state != State.POLLINATED:
		bloom.modulate = Color(1.0, 1.0, 1.0)
		_shimmer_t = 0.0
	seed_pod.visible = state == State.SEED_GROWING
	if seed_pod.visible:
		seed_pod.scale = Vector2.ONE * (seed_progress / 100.0)
		seed_pod.color = PlantData.seed_color(hybrid_result)
