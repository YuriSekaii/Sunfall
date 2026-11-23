class_name Sfx
extends RefCounted

const MIX_RATE := 22050
const REF_MAP := {
	"swing": "melee_swing",
	"hit": "melee_hit",
	"kick": "melee_hit",
	"turret": "turret_shot",
	"zombie_groan": "zombie_groan",
	"zombie_attack": "zombie_attack",
	"footstep": "footstep",
}
static var _cache: Dictionary = {}


static func play(parent: Node, name_key: String, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	if parent == null or DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = null
	if REF_MAP.has(name_key):
		stream = RefAssets.get_audio(String(REF_MAP[name_key]))
	if stream == null:
		stream = _get_stream(name_key)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	parent.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func _get_stream(key: String) -> AudioStreamWAV:
	if _cache.has(key):
		return _cache[key]
	var clip: AudioStreamWAV = null
	match key:
		"swing":
			clip = _synth(0.14, 340.0, 120.0, 0.35, 0.45)
		"hit":
			clip = _synth(0.11, 160.0, 55.0, 0.7, 0.6)
		"kick":
			clip = _synth(0.16, 130.0, 42.0, 0.85, 0.5)
		"climb":
			clip = _synth(0.13, 180.0, 290.0, 0.35, 0.35)
		"loot":
			clip = _synth(0.18, 520.0, 880.0, 0.5, 0.05)
		"build":
			clip = _synth(0.15, 220.0, 140.0, 0.6, 0.3)
		"repair":
			clip = _synth(0.12, 420.0, 620.0, 0.5, 0.15)
		"turret":
			clip = _synth(0.09, 680.0, 210.0, 0.65, 0.4)
		"hurt":
			clip = _synth(0.20, 210.0, 95.0, 0.75, 0.35)
		"siren":
			clip = _synth(0.55, 310.0, 460.0, 0.6, 0.05)
		_:
			return null
	_cache[key] = clip
	return clip


static func _synth(duration: float, f0: float, f1: float, amp: float, noise_mix: float) -> AudioStreamWAV:
	var count := maxi(1, int(duration * MIX_RATE))
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 100.0 + f1)
	for i in count:
		var t := float(i) / float(count)
		var env := (1.0 - t) * (1.0 - t)
		var freq := lerpf(f0, f1, t)
		phase += TAU * freq / float(MIX_RATE)
		var tone := sin(phase)
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := clampf((tone * (1.0 - noise_mix) + noise * noise_mix) * amp * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
